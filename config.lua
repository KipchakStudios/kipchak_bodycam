Config = {}

Config.Framework = 'auto'
Config.Inventory = 'auto'
Config.Locale = 'en'
Config.Debug = false

Config.Item = 'bodycam'

Config.AllowedJobs = {
    police = 0,
    sheriff = 0,
    ambulance = 0
}
Config.RequireOnDuty = false

Config.RememberState = true
Config.TurnOffWhenItemRemoved = true
Config.TurnOffWhenUnauthorized = true
Config.TurnOffOnDeath = false
Config.TurnOffOnCuff = false
Config.CheckInterval = 2000

Config.ShowInThirdPerson = true
Config.HideInPauseMenu = true

Config.HideOverlayKey = {
    Enabled = false,
    Key = ''
}

Config.Notify = {
    Enabled = true
}

Config.Sound = {
    Enabled = true,
    Volume = 0.25,
    Nearby = {
        Enabled = false,
        Distance = 6.0
    }
}

Config.Badge = {
    MetadataKey = 'callsign',
    Fallback = 'N/A',
    HideWhenEmpty = true
}

Config.DateTime = {
    Source = 'real',
    Format = 'YYYY-MM-DD HH:mm:ss',
    Use12Hour = false,
    TimezoneOffset = 0
}

Config.Serial = {
    Enabled = true,
    Prefix = 'KS-BC'
}

Config.Overlay = {
    Position = 'top-right',
    OffsetX = 0,
    OffsetY = 0,
    Scale = 1.0,
    Font = 'mono',
    CustomFont = {
        File = '',
        Family = ''
    },
    TextColor = '#ffffff',
    Uppercase = true,
    NameFormat = 'initial',
    Shadow = true,
    ShadowStrength = 0.85,
    RecColor = '#ff2b2b',
    RecBlinkSpeed = 1.0,
    Strip = {
        Enabled = false,
        Opacity = 0.35
    },
    Fields = {
        Rec = true,
        ModeLabel = true,
        DateTime = true,
        Department = true,
        Officer = true,
        Badge = true,
        Serial = true,
        Unit = true,
        Speed = true,
        Lights = true,
        Siren = true
    },
    Labels = {
        Rec = false,
        Dashcam = false,
        Live = false,
        Officer = false,
        Badge = false,
        Unit = false,
        Speed = false,
        Lights = false,
        Siren = false,
        On = false,
        Off = false
    }
}

Config.Logo = {
    Enabled = true,
    Size = 56,
    Position = 'left',
    Opacity = 0.9
}

Config.Departments = {
    police = {
        label = 'LSPD',
        subtitle = 'Patrol Division',
        logo = 'lspd.svg',
        color = '#4f8cff',
        badgeLabel = 'BADGE'
    },
    sheriff = {
        label = 'BCSO',
        subtitle = 'Sheriff Office',
        logo = 'bcso.svg',
        color = '#d9a441',
        badgeLabel = 'BADGE'
    },
    sahp = {
        label = 'SAHP',
        subtitle = 'Highway Patrol',
        logo = 'sahp.svg',
        color = '#e3c04f',
        badgeLabel = 'BADGE'
    },
    ambulance = {
        label = 'EMS',
        subtitle = 'Medical Services',
        logo = 'ems.svg',
        color = '#ff5a5a',
        badgeLabel = 'UNIT'
    }
}

Config.DefaultDepartment = {
    label = false,
    subtitle = false,
    logo = false,
    color = '#ffffff',
    badgeLabel = false
}

Config.Effects = {
    Vignette = {
        Enabled = true,
        Intensity = 0.55
    },
    Grain = {
        Enabled = false,
        Intensity = 0.05,
        Animated = false
    },
    Frame = {
        Enabled = true,
        Intensity = 0.5
    },
    Timecycle = {
        Enabled = false,
        Modifier = 'scanline_cam_cheap',
        Strength = 0.3
    }
}

Config.Dashcam = {
    Enabled = true,
    OverlayMode = 'camera',
    VehicleClasses = { 18 },
    Models = {},
    SpeedUnit = 'kmh',
    UnitSource = 'plate',
    UnitNames = {},
    Camera = {
        Enabled = true,
        Key = 'J',
        Fov = 70.0,
        DefaultOffset = vec3(0.0, 0.45, 0.62),
        Offsets = {}
    }
}

Config.LiveView = {
    Enabled = true,
    Command = 'bodycamview',
    MinGrade = 3,
    Jobs = {
        police = true,
        sheriff = true
    },
    RequireOnDuty = true,
    Locations = {},
    LocationRadius = 2.0,
    SameJobOnly = false,
    NotifyTarget = false,
    Fov = 85.0,
    BodyOffset = vec3(0.0, 0.28, 0.42),
    BodyPitch = -4.0,
    SignalTimeout = 10,
    AllowSelfView = false
}
