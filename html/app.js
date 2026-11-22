(() => {
    const FONTS = {
        mono: "'Consolas', 'Lucida Console', 'DejaVu Sans Mono', monospace",
        courier: "'Courier New', Courier, monospace",
        sans: "'Segoe UI', 'Helvetica Neue', Arial, sans-serif",
        condensed: "'Bahnschrift', 'Arial Narrow', 'Segoe UI', sans-serif"
    };

    const el = (id) => document.getElementById(id);
    const root = document.documentElement.style;
    const body = document.body;
    const hud = el('hud');
    const logo = el('logo');

    const state = {
        cfg: null,
        own: null,
        view: null,
        viewer: false,
        index: 0,
        total: 0,
        frame: { visible: false, mode: 'bodycam' },
        offset: 0,
        signal: true,
        audio: null,
        logoSrc: ''
    };

    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'kipchak_bodycam';

    const post = (name, data) => {
        fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).catch(() => {});
    };

    const clamp = (value, min, max) => Math.min(max, Math.max(min, Number(value) || 0));
    const pad = (value, len = 2) => String(value).padStart(len, '0');
    const setText = (id, text) => {
        const node = el(id);
        const value = text == null ? '' : String(text);
        if (node.textContent !== value) node.textContent = value;
    };

    const resolveAsset = (file, folder) => {
        if (!file) return '';
        if (/^(https?:|nui:|data:)/i.test(file)) return file;
        return `${folder}/${file}`;
    };

    const makeGrain = () => {
        const size = 220;
        const canvas = document.createElement('canvas');
        canvas.width = size;
        canvas.height = size;
        const ctx = canvas.getContext('2d');
        const img = ctx.createImageData(size, size);
        for (let i = 0; i < img.data.length; i += 4) {
            const v = Math.random() * 255;
            img.data[i] = v;
            img.data[i + 1] = v;
            img.data[i + 2] = v;
            img.data[i + 3] = 255;
        }
        ctx.putImageData(img, 0, 0);
        document.querySelector('.fx-grain').style.backgroundImage = `url(${canvas.toDataURL('image/png')})`;
    };

    const loadCustomFont = (custom) => {
        if (!custom || !custom.File || !custom.Family || typeof FontFace !== 'function') return;
        const face = new FontFace(custom.Family, `url(${resolveAsset(custom.File, 'fonts')})`);
        face.load().then((loaded) => {
            document.fonts.add(loaded);
            root.setProperty('--bc-font', `'${custom.Family}', ${FONTS.mono}`);
        }).catch(() => {});
    };

    const applyConfig = (cfg) => {
        state.cfg = cfg;
        const o = cfg.overlay;
        const fx = cfg.effects;

        root.setProperty('--bc-color', o.TextColor || '#ffffff');
        root.setProperty('--bc-scale', clamp(o.Scale, 0.4, 3));
        root.setProperty('--bc-rec-color', o.RecColor || '#ff2b2b');
        root.setProperty('--bc-rec-speed', `${clamp(o.RecBlinkSpeed, 0.2, 5)}s`);
        root.setProperty('--bc-offset-x', `${(Number(o.OffsetX) || 0) / 10.8}vh`);
        root.setProperty('--bc-offset-y', `${(Number(o.OffsetY) || 0) / 10.8}vh`);

        const shadow = clamp(o.ShadowStrength, 0, 1);
        root.setProperty('--bc-shadow', o.Shadow ? `0 0 0.2em rgba(0,0,0,${shadow}), 0 0.06em 0.12em rgba(0,0,0,${shadow})` : 'none');
        root.setProperty('--bc-strip', o.Strip && o.Strip.Enabled ? `rgba(0,0,0,${clamp(o.Strip.Opacity, 0, 1)})` : 'transparent');

        if (o.Font === 'custom') {
            loadCustomFont(o.CustomFont);
        } else {
            root.setProperty('--bc-font', FONTS[o.Font] || o.Font || FONTS.mono);
        }

        const lg = cfg.logo;
        root.setProperty('--bc-logo-size', `${clamp(lg.Size, 8, 400) / 10.8}vh`);
        root.setProperty('--bc-logo-opacity', clamp(lg.Opacity, 0, 1));

        const position = ['top-left', 'top-right', 'bottom-left', 'bottom-right'].includes(o.Position) ? o.Position : 'top-right';
        const logoPos = ['left', 'right', 'top', 'bottom'].includes(lg.Position) ? lg.Position : 'left';
        hud.className = `pos-${position} logo-${logoPos}${o.Uppercase ? ' upper' : ''}`;

        el('fx').querySelector('.fx-vignette').style.display = fx.Vignette.Enabled ? '' : 'none';
        root.setProperty('--bc-vignette', clamp(fx.Vignette.Intensity, 0, 1));

        const grain = document.querySelector('.fx-grain');
        grain.style.display = fx.Grain.Enabled ? '' : 'none';
        root.setProperty('--bc-grain', clamp(fx.Grain.Intensity, 0, 1));

        const frame = document.querySelector('.fx-frame');
        frame.style.display = fx.Frame.Enabled ? '' : 'none';
        const f = clamp(fx.Frame.Intensity, 0, 1);
        root.setProperty('--bc-frame-radius', `${2 + f * 7}vh`);
        root.setProperty('--bc-frame-outer', `rgba(0,0,0,${Math.min(1, 0.45 + f * 0.6)})`);
        root.setProperty('--bc-frame-inner', `rgba(0,0,0,${f * 0.75})`);
        root.setProperty('--bc-frame-blur', `${3 + f * 8}vh`);
        root.setProperty('--bc-corner', `rgba(255,255,255,${0.12 + f * 0.3})`);

        const fields = o.Fields || {};
        document.querySelectorAll('[data-field]').forEach((node) => {
            node.classList.toggle('hide', fields[node.dataset.field] === false);
        });
        el('serial').classList.toggle('hide', fields.Serial === false || !cfg.serial);

        const l = cfg.labels;
        setText('recText', l.Rec);
        setText('lblOfficer', l.Officer);
        setText('lblUnit', l.Unit);
        setText('lblSpeed', l.Speed);
        setText('lblLights', l.Lights);
        setText('lblSiren', l.Siren);
        setText('speedUnit', l.SpeedUnit);
        setText('liveTag', l.Live);
        setText('hintText', l.Hint);

        render();
    };

    const profileFor = (info) => {
        const cfg = state.cfg;
        const base = cfg.defaultDepartment || {};
        const profile = (info && cfg.departments && cfg.departments[info.job]) || {};
        return {
            label: profile.label || base.label || (info && info.jobLabel) || '',
            subtitle: profile.subtitle || base.subtitle || '',
            logo: profile.logo !== undefined ? profile.logo : base.logo,
            color: profile.color || base.color || '#ffffff',
            badgeLabel: profile.badgeLabel || base.badgeLabel || cfg.labels.Badge
        };
    };

    const renderInfo = (info) => {
        if (!state.cfg) return;
        const profile = profileFor(info);
        root.setProperty('--bc-accent', profile.color);
        setText('deptName', profile.label);
        setText('deptSub', profile.subtitle);
        setText('officer', info ? info.name : '');
        setText('lblBadge', profile.badgeLabel);
        setText('badge', info ? info.badge : '');
        el('badge').parentElement.classList.toggle('empty', !(info && info.badge));
        setText('serial', info ? info.serial : '');

        const src = state.cfg.logo.Enabled && profile.logo ? resolveAsset(profile.logo, 'logos') : '';
        if (src !== state.logoSrc) {
            state.logoSrc = src;
            logo.classList.remove('show');
            if (src) logo.src = src;
            else logo.removeAttribute('src');
        }
    };

    logo.addEventListener('load', () => logo.classList.add('show'));
    logo.addEventListener('error', () => logo.classList.remove('show'));

    const renderVehicle = (vehicle) => {
        if (!vehicle || !state.cfg) return;
        const l = state.cfg.labels;
        setText('unit', vehicle.unit);
        setText('speed', pad(Math.max(0, vehicle.speed | 0), 3));
        setText('lights', vehicle.lights ? l.On : l.Off);
        setText('siren', vehicle.siren ? l.On : l.Off);
        el('lights').classList.toggle('on', !!vehicle.lights);
        el('siren').classList.toggle('on', !!vehicle.siren);
    };

    const render = () => {
        if (!state.cfg) return;
        const frame = state.frame;
        const info = state.viewer ? state.view : state.own;
        const visible = !!info && (state.viewer || frame.visible);
        const dash = visible && frame.mode === 'dashcam';
        body.classList.toggle('on', visible);
        body.classList.toggle('viewer', state.viewer);
        body.classList.toggle('dash', dash);
        body.classList.toggle('nosignal', state.viewer && !state.signal);
        setText('modeTag', dash ? state.cfg.labels.Dashcam : '');
        setText('hintIndex', state.viewer && state.total > 1 ? `${state.index}/${state.total}` : '');
        if (dash) renderVehicle(frame.vehicle);
        tick();
    };

    const formatDate = (d, fmt, use12) => {
        let pattern = fmt || 'YYYY-MM-DD HH:mm:ss';
        if (use12) {
            pattern = pattern.replace(/HH/g, 'hh');
            if (!/A/.test(pattern)) pattern += ' A';
        }
        const tokens = {
            YYYY: d.y,
            YY: pad(d.y % 100),
            MM: pad(d.mo),
            DD: pad(d.d),
            HH: pad(d.h),
            hh: pad(d.h % 12 || 12),
            mm: pad(d.mi),
            ss: pad(d.s),
            A: d.h >= 12 ? 'PM' : 'AM'
        };
        return pattern.replace(/YYYY|YY|MM|DD|HH|hh|mm|ss|A/g, (t) => tokens[t]);
    };

    const tick = () => {
        if (!state.cfg || !body.classList.contains('on')) return;
        const dt = state.cfg.dateTime;
        let d = state.frame.game;
        if (dt.Source !== 'game' || !d) {
            const now = new Date(Date.now() + state.offset + (Number(dt.TimezoneOffset) || 0) * 3600000);
            d = {
                y: now.getUTCFullYear(),
                mo: now.getUTCMonth() + 1,
                d: now.getUTCDate(),
                h: now.getUTCHours(),
                mi: now.getUTCMinutes(),
                s: now.getUTCSeconds()
            };
        }
        setText('time', formatDate(d, dt.Format, dt.Use12Hour));
    };

    const beep = (kind, volume) => {
        try {
            state.audio = state.audio || new (window.AudioContext || window.webkitAudioContext)();
        } catch (e) {
            return;
        }
        const ctx = state.audio;
        if (ctx.state === 'suspended') ctx.resume();
        const vol = clamp(volume, 0, 1);
        const pattern = kind === 'on'
            ? [[1180, 0, 0.075], [1760, 0.11, 0.09]]
            : [[1760, 0, 0.075], [880, 0.11, 0.14]];
        const start = ctx.currentTime + 0.02;
        pattern.forEach(([freq, at, len]) => {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            const t = start + at;
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, t);
            gain.gain.setValueAtTime(0, t);
            gain.gain.linearRampToValueAtTime(vol, t + 0.006);
            gain.gain.setValueAtTime(vol, t + len - 0.02);
            gain.gain.linearRampToValueAtTime(0, t + len);
            osc.connect(gain).connect(ctx.destination);
            osc.start(t);
            osc.stop(t + len + 0.02);
        });
    };

    const syncTime = (epoch) => {
        if (typeof epoch === 'number') state.offset = epoch * 1000 - Date.now();
    };

    let switchTimer = null;

    const handlers = {
        config: (data) => applyConfig(data),
        time: (data) => {
            syncTime(data.epoch);
            tick();
        },
        info: (data) => {
            state.own = data.info || null;
            if (!state.viewer) renderInfo(state.own);
            render();
        },
        frame: (data) => {
            state.frame = {
                visible: !!data.visible,
                mode: data.mode || 'bodycam',
                vehicle: data.vehicle || null,
                game: data.game || null
            };
            render();
        },
        viewer: (data) => {
            state.viewer = !!data.active;
            if (state.viewer) {
                state.view = data.info || null;
                state.index = data.index || 1;
                state.total = data.total || 1;
                syncTime(data.time);
                renderInfo(state.view);
            } else {
                state.view = null;
                state.signal = true;
                state.frame = { visible: false, mode: 'bodycam' };
                renderInfo(state.own);
            }
            render();
        },
        signal: (data) => {
            state.signal = !!data.ok;
            const labels = state.cfg ? state.cfg.labels : {};
            setText('signalText', state.signal ? '' : (data.connecting ? labels.Connecting : labels.NoSignal));
            render();
        },
        switch: () => {
            body.classList.remove('switching');
            void body.offsetWidth;
            body.classList.add('switching');
            clearTimeout(switchTimer);
            switchTimer = setTimeout(() => body.classList.remove('switching'), 400);
        },
        beep: (data) => beep(data.kind, data.volume)
    };

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !handlers[data.action]) return;
        handlers[data.action](data);
    });

    makeGrain();
    setInterval(tick, 250);
    post('ready');
})();
