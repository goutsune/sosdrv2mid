#!/usr/bin/env python3

import os, sys, io, math
from struct import *
from midiutil import MIDIFile

NOTE_LEN_OFFSET = 0x10ac
TRACK_PTR_LIST = 0x1402
SC88_RST = b'\x10\x42\x12\x00\x00\x7F\x00\x01'
INSTR_MAP = {
  # SPC: [MSB,LSB,PC, Velocity offset]
  0:     [16, 3,  48,  0.5],  # St. Strings
  1:     [1,  3,  73,    1],  # Flute    :
  2:     [0,  3,  71,    1],  # Clarinet
  3:     [0,  3,  74,    1],  # Recorder
  4:     [1,  3,  60,    1],  # Fr. Horn 2
  5:     [0,  3,  46,    1],  # Harp
  6:     [0,  3,  47,    1],  # Timpani
  7:     [16, 3,   0,    1],  # European Pf
  8:     [3,  3, 124,    1],  # Door         # SFX
  9:     [0,  3,  69,  0.9],  # English Horn
  10:    [2,  3,  45,    1],  # Chamber Pizz
  11:    [2,  3, 120,    1],  # String Slap  # SFX
  12:    [2,  3, 120,    1],  # String Slap  # SFX
  13:    [2,  3, 120,    1],  # String Slap  # SFX
  14:    [2,  3, 120,    1],  # String Slap  # SFX
}

'''Execution plan:
1. Create class to define global sequence state that will store global echo/tempo/detune/timing parameters
2. Creata class to define individual track state, it will be passed sequence class for processing.
3. Create event execution loop that increases tick by 1 and calls track process_tick method, this method
   should advance track state if current tick equals tracks' next_tick state and parses data accordingly.
4. Split gigantic ifelse block inside track into individual class methods that emit midi messages into
   sequence.
'''


def lin_to_exp(x, a=1, b=0.05, in_top=127, out_top=127):

    output = a * (1 - math.exp(-b * x))
    output = output * (out_top / (1 - math.exp(-b * in_top)))
    return int(output)


class Sequence:
  tempo = 0
  tick = 0
  echo_vol = 0
  echo_delay = 0
  echo_feedback = 0
  length_is_table = True

  midi = None
  note_lengths = []

  def __init__(self, output, note_len_tbl):
    self.midi = output
    self.note_lengths = note_len_tbl

  def update_tick(self):
    self.tick = self.tick + 1


class Track:

  sequence = None
  track_id = None
  track = None  # Reference to specific MIDITrack

  done = False
  index = 0
  restart_index = None
  loop_counter = 0
  data = None
  data_offset = None  # RAM Offset for debugging messages
  cmd = None
  reuse_cmd = False

  note_tick = 0  # A value of 0 will mean note-off command is to be sent
  note_period = 0
  note_offset = 0

  sequence_tick = 0 # A value of 0 will mean next command is to be processed
  sequence_period = 0

  playing = False
  note = None
  velocity = 0
  instrument = 0

  def __init__(self, seq, track_id, data, data_offset):
    self.sequence = seq
    self.track_id = track_id
    self.track = seq.midi.tracks[track_id + 1]
    self.data = data
    self.data_offset = data_offset

  def process_tick(self):
    '''Tick processing routine.
    We have 2 separate counters to take care of:
    Note counter: when it reaches zero, we are to send note-off event, and that's it
    Track counter: when it reaches zero, we are to fetch next event in data stream.

    Track event is to be processed by event dispatcher and depending on event type we either
    process it instantly and go to next event, or reload tick counter and bail out.
    '''

    if self.done:
      return

    if self.playing == True:
      self.note_tick -= 1  # It is possible to set note length to 0, effectively allowing
                           # for infinetly playing notes until rest message is received.

    if self.sequence_tick > 0:
      self.sequence_tick -= 1

    # We reached end of note counter, let's send note_off event first
    if self.note_tick == 0 and self.playing == True:
      self.track.addNoteOff(
        self.track_id,
        self.note,
        self.sequence.tick,
        self.velocity)

      self.playing = False  # To avoid sending note-off every tick

    while self.sequence_tick == 0 and not self.done:
        self.process_cmd()

  def process_cmd(self):
    '''Dispatch loop for command processing.
    Possible cases:
    0  00~7F - Arguments to previous stored command.
    1. 80~B0 - Set note length, yes, 0xB0 included
    2. B1~BF - Global commands, executed instantly
    3. C0~CF - Voice commands, these reset tick timer after execution
    4. D0~FF - Note commands, these play notes
    '''

    stream_byte = self.data[self.index]

    # For bytes which are not raw command/note arguments, update
    # track cmd (including notes) and switch on it
    if stream_byte < 0x80:
      cmd = self.cmd
    else:
      cmd = stream_byte
      self.index += 1  # Shift data pointer to the first agument to be read

    # Store voice commands and notes into track state for reuse
    if cmd >= 0xC0:
      self.cmd = cmd

    print('M:{:2d} T:{:3d} Tr:{:01d} Ofc:{:04X} Executing {:02X}'.format(
      self.sequence.tick // 192 + 1,
      self.sequence.tick % 192,
      self.track_id,
      self.index,
      cmd
    ))

    match cmd:  # Matches anyting in 0x80~0xFF range

      case tick_len if tick_len in range(0x80, 0xB1):
        tick_len -= 0x80  # Clear byte stream offset
        if self.sequence.length_is_table:
          self.sequence_period = self.sequence.note_lengths[tick_len]
        else:
          self.sequence_period = tick_len

      # ###################### BX commands, these are instant

      case 0xB1:  # Track end
        self.done = True

      case 0xB5:  # Loop start
        self.restart_index = self.index
        self.loop_counter = 0

      case 0xB6:  # Loop end
        # Hack, but exit when there is 0xB1 event after loop end
        # TODO: Introduce loop_done status to try and capture whole-song
        #       loop completitions.
        if self.data[self.index + 1] == 0xB1:
          self.done = True

        num_loops = self.data[self.index]

        if self.loop_counter < num_loops or num_loops == 0:
          self.index = self.restart_index
        else:
          # Otherwise we advance normally and exit loop
          self.index += 1

        self.loop_counter += 1

      case 0xB7 | 0xBD:  # Reload track timer without note-off
        self.sequence_tick = self.sequence_period

      case 0xB8 | 0xBC:
        # Use unknown, 1 argument
        self.index += 1

      case 0xBA:  # Set note offset
        self.note_offset = self.data[self.index] - 0x40
        self.index += 1

      case 0xBB:  # Set Echo
        # TODO: Implement this?
        self.index += 3

      case 0xBE:  # Switch tick length mode
        length_is_table = bool(self.data[self.index] == 1)

        self.sequence.length_is_table = length_is_table
        self.index += 1

      case 0xBF:  # Force-send note-off event and reload timer
        if self.note is not None:
          self.track.addNoteOff(
            self.track_id,
            self.note,
            self.sequence.tick,
            self.velocity)
          self.playing = False

        self.sequence_tick = self.sequence_period

      # ####################### CX commands
      # These commands restart tick counter

      case 0xC0:  # Set Tempo
        raw_tempo = self.data[self.index] # TODO: How is this properly calculated?

        timer_div = 5000 / raw_tempo  # $1388/X in driver
        speed = 8000 / timer_div  # Speed in Hz, it seems
        midi_tempo = speed * 1.25  # Beware, magic number

        self.sequence.midi.addTempo(0, self.sequence.tick, midi_tempo)

        self.index += 1

      case 0xC1:  # Set Instrument
        raw_instrument = self.data[self.index]

        # Do some remapping to make things sound decent from the start
        self.track.addControllerEvent(
          self.track_id,
          self.sequence.tick,
          0,   # Bank MSB
          INSTR_MAP[raw_instrument][0],
          insertion_order=3)
        self.track.addControllerEvent(
          self.track_id,
          self.sequence.tick,
          32,  # Bank LSB
          INSTR_MAP[raw_instrument][1],
          insertion_order=4)
        self.track.addProgramChange(
          self.track_id,
          self.sequence.tick,
          INSTR_MAP[raw_instrument][2],
          insertion_order=5)  # PC

        self.index += 1

      case 0xC2:  # Set Volume
        raw_volume = self.data[self.index]

        # Normalize to 7 bit integer
        volume = lin_to_exp(raw_volume, b=0.07)

        self.track.addControllerEvent(
          self.track_id,
          self.sequence.tick,
          7,
          volume,
          insertion_order=100)

        self.index += 1

      case 0xC3:  # Set Pan
        raw_pan = self.data[self.index]

        # From 00 to 7F, then wraps. 0 is right only, 7f is left only.
        # 40 is a bit to the left, 3f is a bit to the right, there is no
        # center.

        # Limit to 7 bits, just like midi
        pan = raw_pan & 0b01111111
        # Reverse value, in midi 0 is left
        pan = 0x7f - pan

        self.track.addControllerEvent(
          self.track_id,
          self.sequence.tick,
          10,
          pan,
          insertion_order=100)

        self.index += 1

      case 0xC4:  # Vibrato Speed
        # TODO: Implement Vibrato Speed
        self.index += 1

      case 0xC5:  # Vibrato Level
        raw_vibrato = self.data[self.index]

        # 00-FF Range, let's just set midi modulation controller to it
        vibrato = raw_vibrato // 2
        self.track.addControllerEvent(
          self.track_id,
          self.sequence.tick,
          1,
          vibrato,
          insertion_order=10)

        self.index += 1

      case 0xC7:  # Sets track tuning offset
        # TODO: Implement this as pitchbend event?
        self.index += 1

      # These are unimplemented and should not appear in track data
      case 0xC6 | 0xC8 | 0xC9 | 0xCA | 0xCB | 0xCC | 0xCD | 0xCE | 0xCF:
        raise NotImplementedError('Driver unknown command: {:02X}'.format(cmd))

      case note if note in range(0xD0, 0x100):

        # Take care of playing note if it is still playing at this point
        if self.playing:
          self.track.addNoteOff(self.track_id, self.note, self.sequence.tick, self.velocity)

        note -= 0xd0  # Remove command offset
        note += self.note_offset  # Apply instrument offset
        note += 36   # Transpose by 3 octaves, seems to be correct
        self.note = note  # Store so we can send note-off later

        # There can be optional note arguments:
        # 0x00~0x31 - Note length
        # 0x32~0x7F - Velocity
        # These can be set only once per tick loop
        length_set = False
        velocity_set = False

        while not (length_set and velocity_set):
          param = self.data[self.index]

          if param <= 0x31 and not length_set:
            self.note_period = self.sequence.note_lengths[param]
            length_set = True
            self.index += 1

          elif 0x32 <= param < 0x80 and not velocity_set:
            velocity = (param - 0x31)
            velocity *= INSTR_MAP[self.instrument][3]  # Add velocity offset
            self.velocity = lin_to_exp(velocity, b=0.06, in_top=0x4f)

            velocity_set = True
            self.index += 1

          else:  # We got normal command, bail out
            break

        self.track.addNoteOn(self.track_id, note, self.sequence.tick, self.velocity)

        # Now we need to restart note ticks
        self.note_tick = self.note_period
        self.playing = True

      case _:  # To catch match bugs
        raise ValueError(f'Got unknown command {cmd}!')

    # Restart track timer for all C0~FF commands
    if cmd in range(0xC0, 0x100):
      self.sequence_tick = self.sequence_period


def main():
  if len(sys.argv) < 2:
    exit(1)

  with open(sys.argv[1], 'rb') as file_h:
    file_h.seek(0x100, os.SEEK_SET)  # SPC RAM image at 0x100
    data = file_h.read(0x10000)      # Read 64K

  output = MIDIFile(
    numTracks=8,
    ticks_per_quarternote=48,      # Try to count by SNES Timer 0
    eventtime_is_ticks=True,
    deinterleave=False
  )

  # Extract tick length table at $10ac, $31 entries
  note_len_tbl = data[NOTE_LEN_OFFSET:NOTE_LEN_OFFSET+0x31]

  # Initializa sequence state, our MIDI instance goes there
  seq = Sequence(output, note_len_tbl)

  # Initialize each track and save them to list
  tracks = []

  for track_id in range(0,8):
    address = TRACK_PTR_LIST + track_id*2
    ptr = unpack('<H', data[address:address+2])[0]
    tracks.append(Track(seq, track_id, data[ptr:], ptr))


  # Add SC88 Reset to the first track
  #output.addSysEx(0, 0, 0x41, SC88_RST)
  # Add "All Sounds Off" and "Reset All Controllers" messages
  for index, track in enumerate(tracks):
    track.track.addControllerEvent(index, 0, 0x78, 0x00, insertion_order=0)
    track.track.addControllerEvent(index, 0, 0x79, 0x00, insertion_order=0)

  # Loop over each track while incrementing tick counter
  while not all([x.done for x in tracks]):
    for track in tracks:
      track.process_tick()

    seq.update_tick()

  # At this point we are happy with all tracks being "done", let's save
  with open(sys.argv[1] + '.mid', 'wb') as file_h:
    output.writeFile(file_h)

if __name__ == '__main__':
  main()
