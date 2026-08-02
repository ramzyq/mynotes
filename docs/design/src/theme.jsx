// Notely — shared theme and primitive components.
// Primary = light amethyst violet #A78BFA per user choice.

const makeTheme = (dark) => ({
  dark,
  // Surfaces
  bg:       dark ? '#0E0B14' : '#FAF8F5',
  surface:  dark ? '#17131F' : '#FFFFFF',
  surface2: dark ? '#1E1928' : '#F3F0EB',
  border:   dark ? 'rgba(255,255,255,0.08)' : 'rgba(28,20,40,0.07)',
  borderStrong: dark ? 'rgba(255,255,255,0.14)' : 'rgba(28,20,40,0.12)',

  // Text
  text:     dark ? '#F5F2FB' : '#1B1427',
  text2:    dark ? 'rgba(245,242,251,0.72)' : 'rgba(27,20,39,0.68)',
  text3:    dark ? 'rgba(245,242,251,0.48)' : 'rgba(27,20,39,0.44)',
  text4:    dark ? 'rgba(245,242,251,0.28)' : 'rgba(27,20,39,0.28)',

  // Brand
  violet:      '#A78BFA',
  violetDeep:  '#7C5CF5',
  violetInk:   dark ? '#D7C6FF' : '#4C1D95',
  violetSoft:  dark ? 'rgba(167,139,250,0.14)' : 'rgba(167,139,250,0.12)',
  violetSoft2: dark ? 'rgba(167,139,250,0.22)' : 'rgba(167,139,250,0.20)',

  // Tonal accents for tag system (re-derived in dark)
  tagFg: (t) => {
    const TAGS = window.NOTELY_TAGS;
    if (!dark) return TAGS[t].fg;
    // brighten tag ink in dark
    const map = {
      School:'#9EC5FF', Dev:'#7DDBA9', Projects:'#D1B3FF',
      Career:'#F2C08A', Ideas:'#F5A6CE', Personal:'#C7C8D0',
      Research:'#8ED6E0', Travel:'#F59FB1',
    };
    return map[t] || TAGS[t].fg;
  },
  tagBg: (t) => {
    const TAGS = window.NOTELY_TAGS;
    if (!dark) return TAGS[t].bg;
    const map = {
      School:'rgba(62,130,255,0.16)', Dev:'rgba(16,185,129,0.16)',
      Projects:'rgba(167,139,250,0.18)', Career:'rgba(245,158,11,0.16)',
      Ideas:'rgba(236,72,153,0.16)', Personal:'rgba(180,180,190,0.14)',
      Research:'rgba(6,182,212,0.16)', Travel:'rgba(244,63,94,0.16)',
    };
    return map[t] || TAGS[t].bg;
  },
  tagDot: (t) => window.NOTELY_TAGS[t]?.dot || '#999',
});

// Fonts: Geist (modern UI) + Instrument Serif (display moments)
const FONT_STACK = `'Geist', -apple-system, BlinkMacSystemFont, 'SF Pro Text', system-ui, sans-serif`;
const FONT_DISPLAY = `'Instrument Serif', 'Iowan Old Style', Georgia, serif`;
const FONT_MONO = `'JetBrains Mono', 'SF Mono', ui-monospace, monospace`;

// ──────────────────────────────────────
// Tag pill
// ──────────────────────────────────────
function TagPill({ name, theme, small = false, outlined = false, style = 'pill' }) {
  const fg = theme.tagFg(name);
  const bg = theme.tagBg(name);
  const dot = theme.tagDot(name);

  if (style === 'dot') {
    return (
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 5,
        fontSize: 11.5, fontWeight: 500, color: theme.text2,
        fontFamily: FONT_STACK, letterSpacing: -0.1,
      }}>
        <span style={{ width: 6, height: 6, borderRadius: 4, background: dot }} />
        {name}
      </span>
    );
  }

  if (outlined) {
    return (
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 4,
        fontSize: small ? 10 : 11, fontWeight: 500, color: fg,
        fontFamily: FONT_STACK, letterSpacing: -0.05,
        padding: small ? '1px 6px' : '2px 8px',
        borderRadius: 999,
        border: `1px solid ${fg}33`,
        background: 'transparent',
      }}>
        <span style={{ width: 5, height: 5, borderRadius: 3, background: dot }} />
        {name}
      </span>
    );
  }

  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center',
      fontSize: small ? 10 : 11, fontWeight: 600, color: fg,
      fontFamily: FONT_STACK, letterSpacing: 0,
      padding: small ? '2px 7px' : '3px 9px',
      borderRadius: 6,
      background: bg,
      lineHeight: 1.2,
    }}>
      {name}
    </span>
  );
}

// ──────────────────────────────────────
// Avatar — purple gradient circle + initial
// ──────────────────────────────────────
function Avatar({ size = 32, initial = 'M', ring = false, theme }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'linear-gradient(135deg, #C4A7FF 0%, #8B5CF6 55%, #5B21B6 100%)',
      color: '#fff', fontFamily: FONT_STACK, fontWeight: 600,
      fontSize: size * 0.42, letterSpacing: -0.2,
      boxShadow: ring ? `0 0 0 2px ${theme.surface}, 0 0 0 3.5px ${theme.violet}` : '0 1px 2px rgba(60,30,120,0.25)',
      position: 'relative', overflow: 'hidden',
      flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(circle at 30% 25%, rgba(255,255,255,0.4), transparent 55%)',
      }}/>
      <span style={{ position: 'relative' }}>{initial}</span>
    </div>
  );
}

// ──────────────────────────────────────
// Notely wordmark — simple purple monogram
// ──────────────────────────────────────
function Wordmark({ theme, size = 18 }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 7,
      fontFamily: FONT_STACK, fontWeight: 600, fontSize: size,
      color: theme.text, letterSpacing: -0.4,
    }}>
      <svg width={size + 4} height={size + 4} viewBox="0 0 24 24">
        <defs>
          <linearGradient id="wm" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#C4A7FF"/>
            <stop offset="1" stopColor="#7C3AED"/>
          </linearGradient>
        </defs>
        <rect x="2" y="2" width="20" height="20" rx="6" fill="url(#wm)"/>
        <path d="M7 17V8l10 9V8" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      Notely
    </div>
  );
}

Object.assign(window, { makeTheme, FONT_STACK, FONT_DISPLAY, FONT_MONO, TagPill, Avatar, Wordmark });
