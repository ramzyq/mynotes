// Sample notes data + tag taxonomy for Notely

const TAGS = {
  School:   { name: 'School',   fg: '#0E4B8C', bg: '#E4EFFC', dot: '#3B82F6' },
  Dev:      { name: 'Dev',      fg: '#0E5E3E', bg: '#DEF2E6', dot: '#10B981' },
  Projects: { name: 'Projects', fg: '#5B2A8C', bg: '#EEE4FB', dot: '#8B5CF6' },
  Career:   { name: 'Career',   fg: '#8A4B0E', bg: '#FBEBD9', dot: '#F59E0B' },
  Ideas:    { name: 'Ideas',    fg: '#8B2161', bg: '#FBE4EF', dot: '#EC4899' },
  Personal: { name: 'Personal', fg: '#4A4A55', bg: '#ECECEF', dot: '#6B7280' },
  Research: { name: 'Research', fg: '#0D5E6B', bg: '#DEF1F4', dot: '#06B6D4' },
  Travel:   { name: 'Travel',   fg: '#8E1E3E', bg: '#FBDEE4', dot: '#F43F5E' },
};

// relative time labels matching Notely's human feel
const NOTES = [
  {
    id: 'n01',
    title: 'Flutter state management — Riverpod vs Bloc',
    preview: 'Riverpod wins on compile-time safety and has no BuildContext requirement. Bloc feels heavier for small screens but scales…',
    tags: ['Dev'],
    updated: '12 min',
    pinned: true,
    accent: 'Projects',
  },
  {
    id: 'n02',
    title: 'Senior design review — prep notes',
    preview: 'Three questions to open with. 1) What decision are we trying to make today 2) Who owns the follow-up 3) Where do we disagree…',
    tags: ['Career', 'Projects'],
    updated: '1 h',
    pinned: true,
  },
  {
    id: 'n03',
    title: 'Compiler class — operational semantics',
    preview: 'Big-step vs small-step. Prof. Vardi prefers small-step for concurrency. Homework set 4 due next Thursday.',
    tags: ['School'],
    updated: '3 h',
    pinned: false,
    hasList: true,
  },
  {
    id: 'n04',
    title: 'Lisbon → Porto itinerary',
    preview: 'Train Fri AM (comboio alfa pendular, 2h40). Livraria Lello Sat morning before lines. Douro valley Sunday.',
    tags: ['Travel', 'Personal'],
    updated: '5 h',
    pinned: false,
  },
  {
    id: 'n05',
    title: 'Notely v2 — ship list',
    preview: 'End-to-end encryption, collaborative notes, offline-first reconciliation, markdown shortcuts, audio memos.',
    tags: ['Projects', 'Dev'],
    updated: 'Yesterday',
    pinned: false,
    hasList: true,
  },
  {
    id: 'n06',
    title: 'Thesis — chapter 3 rewrite',
    preview: 'Restructure around the three empirical claims. Move the literature survey to an appendix. Ask Sarah about the Wong et al. paper.',
    tags: ['School', 'Research'],
    updated: 'Yesterday',
    pinned: false,
  },
  {
    id: 'n07',
    title: 'Interview prep — staff role',
    preview: 'System design: design a collaborative editor. Behavioral: conflict with a PM, how did you resolve. Ask about on-call load.',
    tags: ['Career'],
    updated: '2 d',
    pinned: false,
  },
  {
    id: 'n08',
    title: 'Product idea — reading journal',
    preview: 'Kindle-sync highlights + weekly spaced repetition digest. Zero feeds, zero social. One email on Sunday.',
    tags: ['Ideas', 'Projects'],
    updated: '3 d',
    pinned: false,
  },
  {
    id: 'n09',
    title: 'Firestore offline strategy',
    preview: 'Use the SDK cache for reads; route writes through a local SQLite queue and replay on reconnect. Conflict policy = last-write-wins per field.',
    tags: ['Dev', 'Research'],
    updated: '4 d',
    pinned: false,
  },
  {
    id: 'n10',
    title: 'Grocery + meal plan',
    preview: 'Monday pasta, Tuesday sheet-pan chicken, Wednesday leftovers, Thursday tacos.',
    tags: ['Personal'],
    updated: '1 w',
    pinned: false,
    hasList: true,
  },
];

window.NOTELY_TAGS = TAGS;
window.NOTELY_NOTES = NOTES;
