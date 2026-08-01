// Minimal icon set for Notely — stroke-based, 24px grid.

const Icon = ({ children, size = 22, stroke = 'currentColor', fill = 'none', strokeWidth = 1.8, style = {} }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={stroke}
       strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round"
       style={{ display: 'block', ...style }}>
    {children}
  </svg>
);

const IconSearch = (p) => <Icon {...p}><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></Icon>;
const IconClose  = (p) => <Icon {...p}><path d="M6 6l12 12M18 6 6 18"/></Icon>;
const IconPin    = (p) => <Icon {...p}><path d="M12 2.5 9.5 7 5 8l3.5 3.2L7.5 16l4.5-2.2L16.5 16l-1-4.8L19 8l-4.5-1z"/></Icon>;
const IconPinFilled = (p) => <Icon {...p} fill="currentColor" stroke="none"><path d="M14.1 3.2l-1.1 5.6 4.3 4.1-5.7.5-2.6 5.2-1.8-5.4-5.7-.7 4.7-3.3-.3-5.8 5.3 2.2z"/></Icon>;
const IconSort   = (p) => <Icon {...p}><path d="M4 6h13M4 12h9M4 18h5"/><path d="m17 15 3 3 3-3M20 18V10" /></Icon>;
const IconFilter = (p) => <Icon {...p}><path d="M3 5h18M6 12h12M10 19h4"/></Icon>;
const IconPlus   = (p) => <Icon {...p}><path d="M12 5v14M5 12h14"/></Icon>;
const IconMic    = (p) => <Icon {...p}><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/></Icon>;
const IconCheck  = (p) => <Icon {...p}><path d="m4 12 5 5L20 6"/></Icon>;
const IconMore   = (p) => <Icon {...p} fill="currentColor" stroke="none"><circle cx="5" cy="12" r="1.8"/><circle cx="12" cy="12" r="1.8"/><circle cx="19" cy="12" r="1.8"/></Icon>;
const IconTrash  = (p) => <Icon {...p}><path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/></Icon>;
const IconArchive = (p) => <Icon {...p}><rect x="3" y="5" width="18" height="4" rx="1"/><path d="M5 9v10h14V9M10 13h4"/></Icon>;
const IconSettings = (p) => <Icon {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></Icon>;
const IconList = (p) => <Icon {...p}><path d="M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01"/></Icon>;
const IconGrid = (p) => <Icon {...p}><rect x="4" y="4" width="7" height="7" rx="1.2"/><rect x="13" y="4" width="7" height="7" rx="1.2"/><rect x="4" y="13" width="7" height="7" rx="1.2"/><rect x="13" y="13" width="7" height="7" rx="1.2"/></Icon>;
const IconLogout = (p) => <Icon {...p}><path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/></Icon>;
const IconCloud = (p) => <Icon {...p}><path d="M6 18a4 4 0 0 1-.8-7.9 6 6 0 0 1 11.6 1.1A4 4 0 0 1 17 18H6z"/></Icon>;
const IconChevron = (p) => <Icon {...p}><path d="m9 6 6 6-6 6"/></Icon>;
const IconChevronDown = (p) => <Icon {...p}><path d="m6 9 6 6 6-6"/></Icon>;
const IconMoon = (p) => <Icon {...p}><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></Icon>;
const IconSun = (p) => <Icon {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></Icon>;
const IconSparkle = (p) => <Icon {...p}><path d="M12 3v5M12 16v5M3 12h5M16 12h5M5.5 5.5l3.5 3.5M15 15l3.5 3.5M5.5 18.5 9 15M15 9l3.5-3.5"/></Icon>;
const IconEdit = (p) => <Icon {...p}><path d="M4 20h4l11-11-4-4L4 16v4z"/></Icon>;
const IconBack = (p) => <Icon {...p}><path d="m15 6-6 6 6 6"/></Icon>;

Object.assign(window, {
  IconSearch, IconClose, IconPin, IconPinFilled, IconSort, IconFilter, IconPlus,
  IconMic, IconCheck, IconMore, IconTrash, IconArchive, IconSettings, IconList,
  IconGrid, IconLogout, IconCloud, IconChevron, IconChevronDown, IconMoon, IconSun,
  IconSparkle, IconEdit, IconBack,
});
