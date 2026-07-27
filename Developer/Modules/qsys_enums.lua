-- ##############################################################
--			QSYS Enums
-- ##############################################################
--
-- Centralized enum tables for Get*/layout code, per the QSC-derived plugin
-- convention (source: Q-SYS Plugin spec, components_emulator/docs/
-- qsys-plugins.md § ENUMS). Declared OUTSIDE `if Controls then` in every
-- plugin that requires this module, so the same tables are available in
-- both the design-time pass (GetControls/GetControlLayout) and the runtime
-- pass -- unlike the rest of Developer/Modules, which only load after the
-- `if not Controls and Reflect then return end` guard.
--
-- `Status` is intentionally NOT included here: it is scriptable state
-- (0-5) meant to be re-declared inside `if Controls then` in each plugin
-- that uses it, not a design-time layout enum.

do

	local function makeEnum(t)
		return setmetatable(t, {
			__index = function(_, k) error("Enum key not found: " .. k, 2) end,
			__newindex = function() error("Enum read-only", 2) end,
		})
	end

	ControlType = makeEnum{ BUTTON = "Button", KNOB = "Knob", INDICATOR = "Indicator", TEXT = "Text" }

	ButtonType = makeEnum{
		TOGGLE = "Toggle", MOMENTARY = "Momentary", TRIGGER = "Trigger",
		STATE_TRIGGER = "StateTrigger", ON = "On", OFF = "Off", CUSTOM = "Custom",
	}

	-- Knob ranges (lower/upper): dB -100/20 - Hz 20/20000 - Float +-1e9
	-- Integer +-999999999 - Pan -1/1 - Percent 0/100 - Position 0/1 - Seconds 0/87400
	ControlUnit = makeEnum{
		DB = "dB", HZ = "Hz", FLOAT = "Float", INTEGER = "Integer",
		PAN = "Pan", PERCENT = "Percent", POSITION = "Position", SECONDS = "Seconds",
	}

	IndicatorType = makeEnum{ LED = "Led", METER = "Meter", TEXT = "Text", STATUS = "Status" }

	PinStyle = makeEnum{ INPUT = "Input", OUTPUT = "Output", BOTH = "Both", NONE = "None" }

	LayoutStyle = makeEnum{
		FADER = "Fader", KNOB = "Knob", BUTTON = "Button", TEXT = "Text", METER = "Meter",
		LED = "Led", STATUS = "StatusLight", LIST_BOX = "ListBox", COMBO_BOX = "ComboBox",
		MEDIA = "Media", NONE = "None",
	}

	-- Same values as ButtonType; ButtonStyle is the GetControlLayout render style,
	-- ButtonType is the GetControls logical behavior.
	ButtonStyle = makeEnum{
		TOGGLE = "Toggle", MOMENTARY = "Momentary", TRIGGER = "Trigger",
		STATE_TRIGGER = "StateTrigger", ON = "On", OFF = "Off", CUSTOM = "Custom",
	}

	ButtonVisualStyle = makeEnum{ FLAT = "Flat", GLOSS = "Gloss" }

	MeterStyle = makeEnum{ LEVEL = "Level", REDUCTION = "Reduction", GAIN = "Gain", STANDARD = "Standard" }

	TextBoxStyle = makeEnum{ NORMAL = "Normal", METER = "Meter", NO_BACKGROUND = "NoBackground" }

	HTextAlign = makeEnum{ CENTER = "Center", LEFT = "Left", RIGHT = "Right" }

	VTextAlign = makeEnum{ CENTER = "Center", TOP = "Top", BOTTOM = "Bottom" }

	-- "Text" graphics do not exist in Q-SYS -- use GraphicType.LABEL for static text.
	GraphicType = makeEnum{ LABEL = "Label", GROUP_BOX = "GroupBox", HEADER = "Header", IMAGE = "Image", SVG = "Svg" }

	PropertyType = makeEnum{ STRING = "string", INTEGER = "integer", DOUBLE = "double", BOOLEAN = "boolean", ENUM = "enum" }

	-- GetPins Direction= is lowercase, unlike PinStyle (uppercase) above.
	PinDirection = makeEnum{ INPUT = "input", OUTPUT = "output" }

	Font = makeEnum{
		ROBOTO = "Roboto", MONTSERRAT = "Montserrat", OPEN_SANS = "Open Sans", LATO = "Lato",
		POPPINS = "Poppins", ROBOTO_MONO = "Roboto Mono", ROBOTO_SLAB = "Roboto Slab",
		NOTO_SERIF = "Noto Serif", ADAMINA = "Adamina", DROID_SANS = "Droid Sans", SLABO = "Slabo 27px",
	}

end
