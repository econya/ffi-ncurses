# -*- coding: utf-8; -*-
# ruby-ffi wrapper for ncurses.
#
# Sean O'Halpin
#
# repo & docs: http://github.com/seanohalpin/ffi-ncurses
#
# - version 0.1.0 - 2008-12-04
# - version 0.2.0 - 2009-01-18
# - version 0.3.0 - 2009-01-31
# - version 0.3.3 - 2010-08-24
# - version 0.3.4 - 2010-08-28
# - version 0.3.5 - 2011-01-05
# - version 0.4.0 - 2011-09-06 - boolean types, ACS definitions, Ncurses compatibility
require 'ffi'

# Load typedefs.
require 'ffi-ncurses/typedefs'

# Load autogenerated function signatures.
require 'ffi-ncurses/functions'

# Load alternative character set definitions.
require 'ffi-ncurses/acs'

# Declare module.
module FFI
  module NCurses
    # FFI overwrites the signatures when you call =attach_function= so
    # I keep an untouched deep copy here (used in the Ncurses
    # compatibility layer).
    FUNCTION_SIGNATURES = Marshal.load(Marshal.dump(FUNCTIONS))

    # Make all instance methods module methods too.
    extend self

    VERSION = "0.4.0"
    extend FFI::Library

    # Use `RUBY_FFI_NCURSES_LIB` to specify a colon-separated list of
    # libs you want to try to load, e.g.
    #
    #     RUBY_FFI_NCURSES_LIB=XCurses:ncurses
    #
    # to try to load XCurses (from PDCurses) first, then ncurses.
    if ENV["RUBY_FFI_NCURSES_LIB"].to_s != ""
      LIB_HANDLE = ffi_lib(ENV["RUBY_FFI_NCURSES_LIB"].split(/:/)).first
    else
      LIB_HANDLE = ffi_lib(['ncursesw', 'libncursesw', 'ncurses']).first
    end

    begin
      # These global variables are defined in `ncurses.h`:
      #
      #     chtype acs_map[];
      #     WINDOW * curscr;
      #     WINDOW * newscr;
      #     WINDOW * stdscr;
      #     char ttytype[];
      #     int COLORS;
      #     int COLOR_PAIRS;
      #     int COLS;
      #     int ESCDELAY;
      #     int LINES;
      #     int TABSIZE;
      #
      # Note that the symbol table entry in a shared lib for an
      # exported variable contains a *pointer to the address* of
      # the variable which will be initialized in the process's
      # bss (uninitialized) data segment when the process is
      # initialized.

      # This is unlike methods, where the symbol table entry points to
      # the entry point of the method itself.

      # Variables need another level of indirection because they are
      # *not* shared between process instances - only code is shared.

      # So we define convenience methods to perform the lookup for
      # us. We can't just stash the value returned by
      # `read_pointer` at load time because it's not initialized
      # until after `initscr` has been called.
      symbols = [
                 ["curscr", :pointer],
                 ["newscr", :pointer],
                 ["stdscr", :pointer],
                 ["ttytype", :string],
                 ["COLORS", :int],
                 ["COLOR_PAIRS", :int],
                 ["COLS", :int],
                 ["ESCDELAY", :int],
                 ["LINES", :int],
                 ["TABSIZE", :int],
                ]
      if LIB_HANDLE.respond_to?(:find_symbol)
        symbols.each do |sym, type|
          if handle = LIB_HANDLE.find_symbol(sym)
            define_method sym do
              handle.send("read_#{type}")
            end
            module_function sym
          else
            warn "#{self.name}: #{sym.inspect} not defined"
          end
        end
        # `acs_map` is a special case
        if handle = LIB_HANDLE.find_symbol("acs_map")
          define_method :acs_map do
            handle.get_array_of_uint(0, 128)
          end
        end
      else
        warn "#find_symbol not available - #{symbols.inspect} not defined"
      end
    rescue => e
    end

    # This is used for debugging.
    @unattached_functions = []
    class << self
      def unattached_functions
        @unattached_functions
      end
    end

    # Attach functions.
    FUNCTIONS.each do |func|
      begin
        attach_function(*func)
      rescue Object => e
        unattached_functions << func[0]
      end
    end

    module Color
      COLOR_BLACK   = BLACK   = 0
      COLOR_RED     = RED     = 1
      COLOR_GREEN   = GREEN   = 2
      COLOR_YELLOW  = YELLOW  = 3
      COLOR_BLUE    = BLUE    = 4
      COLOR_MAGENTA = MAGENTA = 5
      COLOR_CYAN    = CYAN    = 6
      COLOR_WHITE   = WHITE   = 7
    end
    include Color

    module Attributes
      # The following definitions have been copied (almost verbatim)
      # from `ncurses.h`.
      NCURSES_ATTR_SHIFT = 8
      def self.NCURSES_BITS(mask, shift)
        ((mask) << ((shift) + NCURSES_ATTR_SHIFT))
      end

      WA_NORMAL     = A_NORMAL     = (1 - 1)
      WA_ATTRIBUTES = A_ATTRIBUTES = NCURSES_BITS(~(1 - 1),0)
      WA_CHARTEXT   = A_CHARTEXT   = (NCURSES_BITS(1,0) - 1)
      WA_COLOR      = A_COLOR      = NCURSES_BITS(((1) << 8) - 1,0)
      WA_STANDOUT   = A_STANDOUT   = NCURSES_BITS(1,8)  # best highlighting mode available
      WA_UNDERLINE  = A_UNDERLINE  = NCURSES_BITS(1,9)  # underlined text
      WA_REVERSE    = A_REVERSE    = NCURSES_BITS(1,10) # reverse video
      WA_BLINK      = A_BLINK      = NCURSES_BITS(1,11) # blinking text
      WA_DIM        = A_DIM        = NCURSES_BITS(1,12) # half-bright text
      WA_BOLD       = A_BOLD       = NCURSES_BITS(1,13) # extra bright or bold text
      WA_ALTCHARSET = A_ALTCHARSET = NCURSES_BITS(1,14)
      WA_INVIS      = A_INVIS      = NCURSES_BITS(1,15)
      WA_PROTECT    = A_PROTECT    = NCURSES_BITS(1,16)
      WA_HORIZONTAL = A_HORIZONTAL = NCURSES_BITS(1,17)
      WA_LEFT       = A_LEFT       = NCURSES_BITS(1,18)
      WA_LOW        = A_LOW        = NCURSES_BITS(1,19)
      WA_RIGHT      = A_RIGHT      = NCURSES_BITS(1,20)
      WA_TOP        = A_TOP        = NCURSES_BITS(1,21)
      WA_VERTICAL   = A_VERTICAL   = NCURSES_BITS(1,22)
    end
    include Attributes

    module Constants
      ERR = -1
      OK = 0
    end
    include Constants

    require 'ffi-ncurses/winstruct'
    include WinStruct

    # These following 'functions' are implemented as macros in ncurses.
    module EmulatedFunctions
      # Note that I'm departing from the NCurses API here - it makes
      # no sense to force people to use pointer return values when
      # these methods have been implemented as macros to make them
      # easy to use in *C*. We have multiple return values in Ruby, so
      # let's use them.
      def getyx(win, y = nil, x = nil)
        res = [NCurses.getcury(win), NCurses.getcurx(win)]
        if y && y.kind_of?(Array) && x.kind_of?(Array)
          y.replace([res[0]])
          x.replace([res[1]])
        end
        res
      end

      def getbegyx(win)
        res = [NCurses.getbegy(win), NCurses.getbegx(win)]
        if y && y.kind_of?(Array) && x.kind_of?(Array)
          y.replace([res[0]])
          x.replace([res[1]])
        end
        res
      end

      def getparyx(win)
        res = [NCurses.getpary(win), NCurses.getparx(win)]
        if y && y.kind_of?(Array) && x.kind_of?(Array)
          y.replace([res[0]])
          x.replace([res[1]])
        end
        res
      end

      def getmaxyx(win, y = nil, x = nil)
        res = [NCurses.getmaxy(win), NCurses.getmaxx(win)]
        if y && y.kind_of?(Array) && x.kind_of?(Array)
          y.replace([res[0]])
          x.replace([res[1]])
        end
        res
      end

      # These have been transliterated from `ncurses.h`.
      def getsyx(y = nil, x = nil)
        if is_leaveok(newscr)
          res = [-1, -1]
        else
          res = getyx(newscr)
        end
        if y && y.kind_of?(Array) && x.kind_of?(Array)
          y.replace([res[0]])
          x.replace([res[1]])
        end
        res
      end

      def setsyx(y, x)
        if y == -1 && x == -1
          leaveok(newscr, true)
        else
          leaveok(newscr, false)
	  wmove(newscr, y, x)
        end
      end

      def self.fixup(function, &block)
        if NCurses.unattached_functions.include?(function)
          block.call
        end
      end

      # Hack for XCurses (PDCurses 3.3) - many more to come I suspect.
      fixup :getch do
        def getch
          wgetch(stdscr)
        end
      end
    end
    include EmulatedFunctions
    extend EmulatedFunctions

    # Include fixes for Mac OS X (mostly macros directly referencing
    # the `WINDOW` struct).
    #
    # FIXME: Might need these for BSD too.
    if defined?(::FFI::Platform::OS) && ::FFI::Platform::OS == "darwin"
      require 'ffi-ncurses/darwin'
      include NCurses::Darwin
    end

    # We need to define our own `initscr` so we can add the ACS
    # constants dynamically.
    private :_initscr

    def initscr
      _initscr
      NCurses.define_acs_constants
      stdscr
    end
  end
end

# Include key definitions.
require 'ffi-ncurses/keydefs'

# Include mouse functions and key definitions.
require 'ffi-ncurses/mouse'
