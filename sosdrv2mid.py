#!/usr/bin/env python3

import os, sys, io
from struct import *
from midiutil import MIDIFile

NOTES = ('C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-')
NOTE_LEN_OFFSET = 0x10ac
TRACK_PTR_LIST = 0x1402

# TODO: I really need to process all tracks at the same time, it seems…
direct_tick_len = False  # If set, use direct value instead of lookup table

def process_track(track_data, ptr, all_data, note_lengths, midi, track):

  done = False
  index = 0
  cur_tick = 0
  cmd = None
  reuse_cmd = False
  refresh_changed = False  # I think this is not needed
  tick_advance = 0 # This is to keep track where to put CX command result.
                   # It seems to matter for C2 the most, not sure other
                   # commands care about it

  note = 0
  note_offset = 0
  cut = 0
  refresh_step = 0
  note_length = 0
  velocity = 0
  instrument = 0
  tempo = 0
  echo_vol = 0
  echo_delay = 0
  echo_feedback = 0

  verbose = True  # Log notes, rests and length changes

  while not done:
    if not reuse_cmd:
      cmd = track_data[index]
    else:
      cmd = last_cmd

    # Store last command in buffer to reuse for shorthands
    if cmd > 0xbf and not reuse_cmd:
      last_cmd = cmd

    # ##################### Note length range

    # 80~AF Note length
    if cmd > 0x7f and cmd <= 0xb0:
      # Driver seems to do SBC with carry bit unset, that causes offset-by-1 error
      if direct_tick_len:
        refresh_step = cmd - 0x7f - 1
      else:
        refresh_step = note_lengths[cmd - 0x7f - 1]

      # Store this, just in case....
      refresh_changed = True

      if verbose:
        print('{:5d}: Set period to {} ticks'.format(cur_tick, refresh_step))

      index += 1

    # ###################### BX commands

    # B5 Set loop start
    elif cmd == 0xb5:
      index +=1
      print('{:5d}: Set Restart to {:04X}'.format(
        cur_tick,
        ptr+index))

    # B6 End / loop end
    elif cmd == 0xb6:
      print('Reached end of track {} at {:04X}!'.format(track+1, ptr+index))
      print('================================\n')
      done = True

    # BA Set Note offset
    elif cmd == 0xba:
      index += 1
      # This is mostly used to set octave, because note range is just 48 notes
      note_offset = track_data[index] - 0x40  # no carry bug this time
      print('{:5d}: Set note offset to {}'.format(
        cur_tick,
        note_offset
      ))
      index += 1

    # BB Set Echo
    elif cmd == 0xbb:
      # BB VV DD FF
      # Volume passed as-is,
      # Delay is set to 4 if less than 4,
      # Feedback passed as-is
      index += 1
      echo_vol = track_data[index]

      index += 1
      echo_delay = track_data[index]
      if echo_delay < 4:
        echo_delay = 4

      index += 1
      echo_feedback = track_data[index]

      # TODO: Pass this as reverb level to channel, maybe?
      print('{:5d}: Set echo vol:{:02X} del:{:02X} fdb:{:02X}'.format(
        cur_tick,
        echo_vol,
        echo_delay,
        echo_feedback))
      index += 1

    # B8 Set track status lower nibble
    elif cmd == 0xb8:
      index += 1
      param = track_data[index]
      print('{:5d}: Set track status low: {:02X}'.format(
        cur_tick,
        param))
      index += 1

    # BC Set track status bit 4
    elif cmd == 0xbc:
      # 7f sets track status to 90, that's basically kill all sound
      index +=1
      param = track_data[index]
      if param == 0x7f:
        print('{:5d}: Set track status to note-off'.format(
          cur_tick))
      else:
        print('{:5d}: Unknown track status argument: {:02X}'.format(
          cur_tick,
          param))

      index +=1

    # B7 Exdend note
    elif cmd == 0xb7:
      tick_advance = 0
      if verbose:
        print('{:5d}: Extend len: {}'.format(
          cur_tick,
          refresh_step
        ))

      cur_tick += refresh_step
      index += 1

    # BE Set direct tick mode
    elif cmd == 0xbe:
      index += 1
      # If enabled, all note length are directly specified length in ticks
      # By default driver uses lookup table
      direct_tick_len = bool(track_data[index] == 1)


    # BF Rest
    elif cmd == 0xbf:
      tick_advance = 0
      if verbose:
        print('{:5d}: Rest len: {}'.format(
          cur_tick,
          refresh_step
        ))

      cur_tick += refresh_step
      index += 1

    # ####################### CX commands

    # C0 Set Tempo:
    elif cmd == 0xc0:
      # C0 XX
      if not reuse_cmd:
        index += 1
      else:
        reuse_cmd = False

      _arg = track_data[index]  # TODO: How is this properly calculated?
      _timer_div = 5000 / _arg  # $1388/X in driver

      speed = 8000 / _timer_div # Speed in Hz
      print('{:5d}: Set timer speed to {}Hz ~{} BPM?'.format(
        cur_tick,
        speed,
        speed *1.2
      ))
      midi.addTempo(track, cur_tick+tick_advance, speed * 1.2)  # Beware, magic number
      index += 1

    # C1 Set instrument
    elif cmd == 0xc1:
      # C1 XX
      if not reuse_cmd:
        index += 1
      else:
        reuse_cmd = False

      instrument = track_data[index]
      print('{:5d}: Set instrument to {}'.format(
        cur_tick,
        instrument
      ))
      midi.addProgramChange(track, track, cur_tick+tick_advance, instrument)
      index += 1

    # C2 Set volume
    elif cmd == 0xc2:
      if not reuse_cmd:
        index += 1
      else:
        reuse_cmd = False

      volume = track_data[index]
      # 00-FF range, but the value is directly cotrolling gain register
      # on the dsp. The tracks generally expect to be 1/8 volume at most to allow
      # for mixing with no clipping, let's assume that too.

      # Volume cmd takes 1 tick to execute, meaning it can be set while a note is
      # playing.

      # if volume > 0x32:  # Assume direct volume level if we are higher than that
        # _vol = volume
        # print('{:5d}: Track volume is above 50/255, not normalizing!'.format(cur_tick))
      # else:
        # _vol = volume*8

      # Normalize to 7 bit integer
      # _vol = _vol // 2
      # print('{:5d}: Set volume to {}'.format(
        # cur_tick,
        # _vol
      # ))

      #midi.addControllerEvent(track, track, cur_tick+tick_advance, 7, _vol)

      # It seems what we want here is to modify instrument's velocity

      index += 1


    # C5 Set Vibrato
    elif cmd == 0xc5:
      if not reuse_cmd:
        index += 1
      else:
        reuse_cmd = False

      vibrato = track_data[index]
      # 00-FF Range, let's just set midi modulation controller to it

      print('{:5d}: Set modulation to {}'.format(
        cur_tick,
        vibrato // 2
      ))

      midi.addControllerEvent(track, track, cur_tick+tick_advance, 1, vibrato // 2)
      index += 1


    # C3 Set panning
    elif cmd == 0xc3:
      if not reuse_cmd:
        index += 1
      else:
        reuse_cmd = False

      pan = track_data[index]
      # From 00 to 7F, then wraps. 0 is right only, 7f is left only.
      # 40 is a bit to the left, 3f is a bit to the right, there is no
      # center.

      # Limit to 7 bits, just like midi
      pan = pan & 0b01111111

      # Reverse value, in midi 0 is left
      pan = 0x7f - pan
      print('{:5d}: Set pan to {}'.format(
        cur_tick,
        pan
      ))

      midi.addControllerEvent(track, track, cur_tick+tick_advance, 10, pan)
      index += 1

    # C2 Stub, 2 bytes
    elif cmd > 0xbf and cmd < 0xd0:
      print('{:5d}: Function {:02X} unimplemented. arg: {:02x}'.format(
        cur_tick,
        cmd,
        track_data[index+1]))

      if not reuse_cmd:
        index += 2
      else:
        index += 1
        reuse_cmd = False

    # ################## D0~FF - Notes

    elif cmd > 0xcf:
      # NN P1? P2?,
      # velocity is set if Param is between $32-$7f
      # note cut is set if arg is between $00-$31
      note = cmd - 0xd0 + note_offset + 36  # Transpose by 3 octaves, seems to be correct
      # Read optional parameters for this note
      note_param_done = False
      note_length_set = False
      velocity_set = False
      tick_advance = 0

      if not reuse_cmd:
        index += 1

      while not note_param_done:
        param = track_data[index]
        if param > 0x7f:
          note_param_done = True
          continue

        # So note cut can be in 0-0x30 range.
        # TODO: Value of 0 enables legato!
        if param < 0x31 and not note_length_set:
          # Note cut parameter is set in ticks, always directly
          note_length = param
          note_length_set = True
          note_param_done = True
          index += 1

        elif param >= 0x31 and not velocity_set:
          velocity = int((param - 0x31) / 0x4d * 0x7f)
          velocity_set = True
          index += 1

        else:
          note_param_done = True

      _octave = note // 12
      _base_n = note % 12

      if note_length:
        _len = note_length
      elif refresh_changed:  # I don't remember why I did this…
        _len = refresh_step + note_length + note_length
        refresh_changed = False
      else:
        _len = refresh_step #+ note_length

      # Let me take a while guess here. Reused params will add ticks to
      # current note without retriggering it
      if not reuse_cmd:

        if verbose:
          print('{:5d}: Playing {}{} len: {} cut: {} vol: {}'.format(
            cur_tick, NOTES[_base_n], _octave, refresh_step, note_length, velocity))

        midi.addNote(track, track, note, cur_tick, _len, velocity)
        cur_tick += refresh_step

      elif reuse_cmd and velocity_set:
        reuse_cmd = False
        if verbose:
          print('{:5d}: Re-playing {}{} len: {} cut: {} vol: {}'.format(
            cur_tick, NOTES[_base_n], _octave, refresh_step, note_length, velocity))

        midi.addNote(track, track, note, cur_tick, _len, velocity)
        cur_tick += refresh_step

      else:

        reuse_cmd = False
        cur_tick += refresh_step

    # ################## Shorthand commands

    elif cmd < 0x80:
      # This will pass down current byte to CMD we stored before,
      # can be CX, or note command
      reuse_cmd = True
      print('{:5d}: Cmd < $7F, will execute {:02x} {:02x}'.format(
        cur_tick,
        last_cmd,
        cmd))

    else:
      print('{:5d}: Got unknown command {:02x}'.format(
        cur_tick,
        cmd))
      index += 1

    # #################### Extra whatever to do after loop

    # Either check if our normal CMD is within CX/Note range,
    # or if we are repeating, check if last cmd was CX/Note
    # if cmd > 0xbf and cmd < 0xd0:
    if cmd == 0xc2:  # Advance only for volume for now

      # Advance internal tick for CX commands to execute them
      # on the playing note
      tick_advance += 1


def main():
  if len(sys.argv) < 2:
    exit(1)

  with open(sys.argv[1], 'rb') as file_h:
    file_h.seek(0x100, os.SEEK_SET)  # SPC RAM image at 0x100
    data = file_h.read(0x10000)      # Read 64K

  output = MIDIFile(
    numTracks=8,
    ticks_per_quarternote=48,      # Try to count by SNES Timer 0
    eventtime_is_ticks=True
  )

  # Extract tick length table at $10ac, $31 entries
  note_len_tbl = data[NOTE_LEN_OFFSET:NOTE_LEN_OFFSET+0x31]

  # Extract 8 tracks ranging from 1 to 8
  for track in range(0, 8):

    address = TRACK_PTR_LIST + track*2
    ptr = unpack('<H', data[address:address+2])[0]

    print('\nBegin processing track {} at {:04X}'.format(track+1, ptr))
    print('================================')

    result = process_track(
      data[ptr:],
      ptr,
      data,
      note_len_tbl,
      output,
      track)

  with open(sys.argv[1] + '.mid', 'wb') as file_h:
    output.writeFile(file_h)

if __name__ == '__main__':
  main()
