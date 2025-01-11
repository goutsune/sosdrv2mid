#!/usr/bin/env python3

import os, sys, io, math, json
from struct import *
from midiutil import MIDIFile

SC88_RST = b'\x10\x42\x12\x00\x00\x7F\x00\x01'

# Example instrument map definition as seen in Wondrous Magic
{
  # SPC: [MSB,LSB,PC, Velocity offset]
  0:     [16, 3,  48,    1],  # St. Strings
  1:     [1,  3,  73,    1],  # Flute    :
  2:     [0,  3,  71,    1],  # Clarinet
  3:     [0,  3,  74,    1],  # Recorder
  4:     [1,  3,  60,    1],  # Fr. Horn 2
  5:     [0,  3,  46,    1],  # Harp
  6:     [0,  3,  47,  0.8],  # Timpani
  7:     [16, 3,   0,    1],  # European Pf
  8:     [3,  3, 124,    1],  # Door         # SFX
  9:     [0,  3,  69,  0.9],  # English Horn
  10:    [2,  3,  45,    1],  # Chamber Pizz
  11:    [2,  3, 120,    1],  # String Slap  # SFX
  12:    [2,  3, 120,    1],  # String Slap  # SFX
  13:    [2,  3, 120,    1],  # String Slap  # SFX
  14:    [2,  3, 120,    1],  # String Slap  # SFX
}

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
  note_lengths = None
  instrument_map = None

  def __init__(self, output, note_len_tbl, instrument_map):
    self.midi = output
    self.note_lengths = note_len_tbl
    self.instrument_map  = instrument_map

  def update_tick(self):
    self.tick = self.tick + 1


class Track:

  sequence = None  # Reference to global sequencer state
  track_id = None  # Track/Channel number
  track = None     # Reference to specific MIDITrack

  playing = False   # Denotes if note tick is non-zero
  finished = False  # Track has finished and will not play anymore
  done = False      # Track has tick counter reloaded and we can go to other track instread
  index = 0         # Absolute data position offset
  restart_stack = None  # Stack for holding nested loop restart positions
  loop_counter = None   # Loop counter stack
  call_stack = None     # Subroutine call stack
  global_loop_happens = False  # Set this when endless loop is reached
  data = None       # Data byte stream
  data_offset = None  # RAM Offset for debugging messages and jumps
  cmd = None        # Last loaded command to be used with shorthands
  note = None       # Last played note for tracking note-off commands
  velocity = None   # Last set velocity for use with shorthands
  instrument = None # Last set instrument for instrument map lookup

  note_tick = 0    # A value of 0 will mean note-off command is to be sent
  note_period = 0  # Timer reload value for notes
  note_offset = 0  # Instrument specific offset in semitones

  sequence_tick = 0    # A value of 0 will mean next command is to be processed
  sequence_period = 0  # Timer reload value for track state

  def __init__(self, seq, track_id, data, data_offset):
    self.sequence = seq
    self.track_id = track_id
    self.track = seq.midi.tracks[track_id + 1]
    self.data = data
    self.data_offset = data_offset
    self.index = data_offset
    self.restart_stack = []
    self.loop_counter = []
    self.call_stack = []

  def disable_track(self):
    self.finished = True

  def jump(self):
    raw_address = int.from_bytes(self.data[self.index:self.index+2], 'little')

    self.index = raw_address

  def gosub(self):
    self.call_stack.append(self.index + 2)
    # Try to detect track end by assuming that direct jump after gosub
    # is the end. There can be no B1 marker, making this tricky.
    if self.data[self.index + 2] == 0xB2:
      self.global_loop_happens = True
    self.jump()

  def returnsub(self):
    self.index = self.call_stack.pop()

  def loop_start(self):
    self.restart_stack.append(self.index)
    self.loop_counter.append(0)

  def loop_end(self):
    # Detect looped track end if there is 0xB1 after endless loop
    if self.data[self.index + 1] == 0xB1 and self.data[self.index] == 0x00:
      self.global_loop_happens = True

    self.loop_counter[-1] += 1  # Increment counter on stack top
    num_loops = self.data[self.index]

    if self.loop_counter[-1] < num_loops or num_loops == 0:
      self.index = self.restart_stack.pop()
      self.restart_stack.append(self.index)
    else:
      # Otherwise we advance normally and exit loop
      self.restart_stack.pop()
      self.loop_counter.pop()
      self.index += 1

  def reload_timer(self):
    self.sequence_tick = self.sequence_period

    # We can have timed commands executed instantly,
    # must not advance tick on them
    if self.sequence_period > 0:
      self.done = True

  def noop_arg(self, step):
    self.index += step

  def set_note_offset(self):
    self.note_offset = self.data[self.index] - 0x40
    self.index += 1

  def tick_mode(self):
    length_is_table = bool(self.data[self.index] == 1)

    self.sequence.length_is_table = length_is_table
    self.index += 1

  def rest(self):
    if self.note is not None and self.playing:
      self.track.addNoteOff(
        self.track_id,
        self.note,
        self.sequence.tick,
        self.velocity)
      self.playing = False

    self.reload_timer()

  def set_tempo(self):
    raw_tempo = self.data[self.index] # TODO: How is this properly calculated?

    timer_div = 5000 / raw_tempo  # $1388/X in driver
    speed = 8000 / timer_div  # Speed in Hz, it seems
    midi_tempo = speed * 1.25  # Beware, magic number

    self.sequence.midi.addTempo(0, self.sequence.tick, midi_tempo)

    self.index += 1

  def set_instrument(self):
    raw_instrument = self.data[self.index]

    self.instrument = raw_instrument

    # Do some remapping to make things sound decent from the start
    self.track.addControllerEvent(
      self.track_id,
      self.sequence.tick,
      0,   # Bank MSB
      self.sequence.instrument_map[self.instrument][0],
      insertion_order=3)

    self.track.addControllerEvent(
      self.track_id,
      self.sequence.tick,
      32,  # Bank LSB
      self.sequence.instrument_map[self.instrument][1],
      insertion_order=4)

    self.track.addProgramChange(
      self.track_id,
      self.sequence.tick,
      self.sequence.instrument_map[self.instrument][2],
      insertion_order=5)  # PC

    self.index += 1

  def set_volume(self):
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

  def set_panning(self):
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

  def set_vibrato_level(self):
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

  def set_tick_period(self, tick_len):
    tick_len -= 0x80  # Clear byte stream offset
    if self.sequence.length_is_table:
      self.sequence_period = self.sequence.note_lengths[tick_len]
    else:
      self.sequence_period = tick_len

  def update_note(self, note):
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

      elif 0x31 < param < 0x80 and not velocity_set:
        velocity = (param - 0x31)
        velocity *= self.sequence.instrument_map[self.instrument][3]  # Add velocity offset
        self.velocity = lin_to_exp(velocity, b=0.06, in_top=0x4f)

        velocity_set = True
        self.index += 1

      else:  # We got normal command, bail out
        break

    self.track.addNoteOn(self.track_id, note, self.sequence.tick, self.velocity)

    # Now we need to restart note ticks
    self.note_tick = self.note_period
    self.playing = True

  def cleanup(self):
    '''Stop playing notes when stopping sequencer.
    This should take of 1-tick NoteOn events at the end of aburptly exited loop
    '''

    if self.note_tick != 0 and self.playing == True:
      self.track.eventList.pop()


  def process_tick(self):
    '''Tick processing routine.
    We have 2 separate counters to take care of:
    Note counter: when it reaches zero, we are to send note-off event, and that's it
    Track counter: when it reaches zero, we are to fetch next event in data stream.

    Track event is to be processed by event dispatcher and depending on event type we either
    process it instantly and go to next event, or reload tick counter and bail out.
    '''

    if self.finished:
      return

    self.done = False  # Reset track status for processing new time tick
    self.global_loop_happens = False

    if self.playing == True:
      self.note_tick -= 1  # It is possible to set note length to 0, effectively allowing
                           # for infinetly playing notes until rest message is received.

    if self.sequence_tick > 0:
      self.sequence_tick -= 1

    # We reached end of note counter, let's send note_off event first
    if self.note_tick == 0 and self.playing:
      self.track.addNoteOff(
        self.track_id,
        self.note,
        self.sequence.tick,
        self.velocity)

      self.playing = False  # To avoid sending note-off every tick

    while self.sequence_tick == 0 and not self.finished:
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
      self.sequence.tick // 192 + 1, self.sequence.tick % 192, self.track_id,
      self.index, cmd))

    match cmd:  # Matches anyting in 0x80~0xFF range

      # ###################### Engine step setup (there is no separate note step setup)

      case tick_len if tick_len in range(0x80, 0xB1):
        self.set_tick_period(tick_len)

      # ###################### BX commands, these are instant

      case 0xB1:  # Track end
        self.disable_track()

      case 0xB2:  # Jump to address
        self.jump()

      case 0xB3:  # Play subroutine
        self.gosub()

      case 0xB4:  # Exit subroutine
        self.returnsub()

      case 0xB5:  # Loop start
        self.loop_start()

      case 0xB6:  # Loop end
        self.loop_end()

      case 0xB7 | 0xBD:  # Reload track timer without note-off
        self.reload_timer()

      case 0xB8 | 0xBC:  # Use unknown, 1 argument
        self.noop_arg(1)

      case 0xB9:  # Fine-tune
        self.noop_arg(1)  # TODO: Implement fine tuning?

      case 0xBA:  # Set note offset
        self.set_note_offset()

      case 0xBB:  # Set Echo
        self.noop_arg(3)  # TODO: Implement this?

      case 0xBE:  # Switch tick length mode
        self.tick_mode()

      case 0xBF:  # Force-send note-off event and reload timer
        self.rest()

      # ###################### CX commands, they restart sequence ticks

      case 0xC0:  # Set Tempo
        self.set_tempo()

      case 0xC1:  # Set Instrument
        self.set_instrument()

      case 0xC2:  # Set Volume
        self.set_volume()

      case 0xC3:  # Set Pan
        self.set_panning()

      case 0xC4:  # Vibrato Speed
        self.noop_arg(1)  # TODO: Implement Vibrato Speed

      case 0xC5:  # Vibrato Level
        self.set_vibrato_level()

      case 0xC7:  # Sets track tuning offset
        self.noop_arg(1)  # TODO: Implement this as pitchbend event?

      # These are unimplemented and should not appear in track data
      case 0xC6 | 0xC8 | 0xC9 | 0xCA | 0xCB | 0xCC | 0xCD | 0xCE | 0xCF:
        raise NotImplementedError('Driver unknown command: {:02X}'.format(cmd))

      # ###################### Notes

      case note if note in range(0xD0, 0x100):
        self.update_note(note)

      case _:  # To catch match bugs
        raise ValueError(f'Got unknown command {cmd:02X}!')

    # Restart track timer for all C0~FF commands, do this at the end to make sure
    # new timer period is fetched first, if any.
    if cmd >= 0xC0:
      self.reload_timer()


def main():
  if len(sys.argv) < 3:
    exit(1)

  with open(sys.argv[2], 'rb') as file_h:
    file_h.seek(0x100, os.SEEK_SET)  # SPC RAM image at 0x100
    data = file_h.read(0x10000)      # Read 64K

  with open(sys.argv[1], 'r') as file_h:
    settings = json.load(file_h)

  # Let's use object hook next time maybe...
  instrument_map = {int(k):v for k,v in settings['instruments'].items()}
  note_length_table = int(settings['note_len'], 0)
  track_pointer_table = int(settings['tracks'], 0)

  output = MIDIFile(
    numTracks=8,
    ticks_per_quarternote=48,      # Try to count by SNES Timer 0
    eventtime_is_ticks=True,
    deinterleave=False
  )

  # Extract tick length table at $10ac, $32 entries
  note_len_tbl = data[note_length_table:note_length_table+0x32]

  # Initializa sequence state, our MIDI instance goes there
  seq = Sequence(output, note_len_tbl, instrument_map)

  # Initialize each track and save them to list
  tracks = []

  for track_id in range(0, 8):
    address = track_pointer_table + track_id*2
    ptr = unpack('<H', data[address:address+2])[0]
    tracks.append(Track(seq, track_id, data, ptr))


  # Add SC88 Reset to the first track
  #output.addSysEx(0, 0, 0x41, SC88_RST)
  # Add "All Sounds Off" and "Reset All Controllers" messages
  for index, track in enumerate(tracks):
    track.track.addControllerEvent(index, 0, 0x78, 0x00, insertion_order=0)
    track.track.addControllerEvent(index, 0, 0x79, 0x00, insertion_order=0)

  loop_counter = 2
  states = [False for x in tracks]  # Prepare global loop tracker list

  # Loop over each track while incrementing tick counter
  while True:
    for track in tracks:
      # This will set all loop flags when it happened on latest track (e.g. echo)
      if track.global_loop_happens:
        states[track.track_id] = True
      track.process_tick()
      if track.finished:
        states[track.track_id] = True

    # Break from the loop if we got all tracks saying global loop has happened
    if all(states):
      states = [False for x in tracks]
      loop_counter -= 1

    if loop_counter == 0:
      for track in tracks:
        track.cleanup()  # Clear hanging notes in the middle of loop exit
      break

    seq.update_tick()

  # At this point we are happy with all tracks being "done", let's save
  with open(sys.argv[2][0:-4] + '.mid', 'wb') as file_h:
    output.writeFile(file_h)

if __name__ == '__main__':
  main()
