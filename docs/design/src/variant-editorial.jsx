// Notely — Variant A: "Editorial"
// The hero design. Clean white cards, serif display title, tonal tag pills,
// elongated violet FAB with a subtle gradient glow.

function VariantEditorial({ theme, tweaks, onOpenAccount, onOpenNote, onOpenCompose }) {
  const [query, setQuery] = React.useState('');
  const [filter, setFilter] = React.useState('All'); // All | Pinned | Recent
  const [sortOpen, setSortOpen] = React.useState(false);
  const [sort, setSort] = React.useState('Updated');
  const [selectMode, setSelectMode] = React.useState(false);
  const [selected, setSelected] = React.useState(new Set());
  const [notes, setNotes] = React.useState(() => window.NOTELY_NOTES.map(n => ({ ...n, archived: false })));
  const [swipeId, setSwipeId] = React.useState(null); // which card has swipe actions revealed
  const [toast, setToast] = React.useState(null);

  const radius = tweaks.radius ?? 18;
  const density = tweaks.density ?? 'cozy'; // compact | cozy | airy
  const tagStyle = tweaks.tagStyle ?? 'pill';
  const fabStyle = tweaks.fabStyle ?? 'pillLabel'; // pillLabel | bottomBar | orb

  const togglePin = (id) => setNotes(ns => ns.map(n => n.id === id ? { ...n, pinned: !n.pinned } : n));
  const archive   = (id) => {
    setNotes(ns => ns.map(n => n.id === id ? { ...n, archived: true } : n));
    setSwipeId(null);
    setToast({ kind: 'archived', id });
    setTimeout(() => setToast(null), 2400);
  };
  const removeMany = () => {
    setNotes(ns => ns.filter(n => !selected.has(n.id)));
    setSelected(new Set()); setSelectMode(false);
  };
  const pinMany = () => {
    setNotes(ns => ns.map(n => selected.has(n.id) ? { ...n, pinned: !n.pinned } : n));
    setSelected(new Set()); setSelectMode(false);
  };
  const toggleSel = (id) => setSelected(s => {
    const n = new Set(s); n.has(id) ? n.delete(id) : n.add(id); return n;
  });

  // filter + sort pipeline
  const visible = React.useMemo(() => {
    let list = notes.filter(n => !n.archived);
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter(n =>
        n.title.toLowerCase().includes(q) ||
        n.preview.toLowerCase().includes(q) ||
        n.tags.some(t => t.toLowerCase().includes(q))
      );
    }
    if (filter === 'Pinned') list = list.filter(n => n.pinned);
    if (filter === 'Recent') list = list.filter(n => /min|h$/.test(n.updated) || n.updated === 'Yesterday');
    return list;
  }, [notes, query, filter]);

  const pinned = visible.filter(n => n.pinned);
  const rest   = visible.filter(n => !n.pinned);

  const rowGap = { compact: 8, cozy: 12, airy: 18 }[density];
  const cardPad = { compact: '12px 14px', cozy: '14px 16px', airy: '18px 18px' }[density];

  return (
    <div style={{
      minHeight: '100%', background: theme.bg, fontFamily: FONT_STACK,
      color: theme.text, position: 'relative', paddingBottom: 140,
    }}>
      {/* ── Header ───────────────────────── */}
      <div style={{ padding: '72px 20px 0' }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 18,
        }}>
          <Wordmark theme={theme} size={17} />
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <IconButton theme={theme} onClick={() => setSelectMode(s => !s)}>
              {selectMode ? <IconClose size={19}/> : <IconCheck size={19}/>}
            </IconButton>
            <button onClick={onOpenAccount} style={{
              all: 'unset', cursor: 'pointer', padding: 2, borderRadius: 999,
            }}>
              <Avatar size={32} initial="M" theme={theme} ring />
            </button>
          </div>
        </div>

        {/* Display title */}
        <div style={{ marginBottom: 4 }}>
          <div style={{
            fontFamily: FONT_DISPLAY, fontSize: 42, lineHeight: 1.02,
            letterSpacing: -1.2, color: theme.text, fontWeight: 400,
          }}>
            Notes<span style={{ color: theme.violet, fontStyle: 'italic', fontWeight: 400 }}>.</span>
          </div>
          <div style={{
            fontSize: 13, color: theme.text3, marginTop: 4,
            letterSpacing: -0.1, display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <span style={{
              width: 6, height: 6, borderRadius: 4, background: '#10B981',
              boxShadow: '0 0 0 3px rgba(16,185,129,0.18)',
            }} />
            {notes.filter(n=>!n.archived).length} notes · synced to iCloud just now
          </div>
        </div>

        {/* Search bar */}
        <div style={{
          marginTop: 22, display: 'flex', alignItems: 'center', gap: 10,
          background: theme.surface, border: `1px solid ${theme.border}`,
          borderRadius: 14, padding: '10px 12px',
          boxShadow: '0 1px 2px rgba(20,10,40,0.02)',
        }}>
          <IconSearch size={18} stroke={theme.text3} />
          <input
            value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="Search notes, tags, content…"
            style={{
              all: 'unset', flex: 1, fontSize: 15, color: theme.text,
              fontFamily: FONT_STACK, letterSpacing: -0.2,
            }}
          />
          {query ? (
            <button onClick={() => setQuery('')} style={{
              all: 'unset', cursor: 'pointer', color: theme.text3,
              display: 'flex',
            }}>
              <IconClose size={16}/>
            </button>
          ) : (
            <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 2,
              fontFamily: FONT_MONO, fontSize: 10.5, color: theme.text3,
              padding: '2px 6px', borderRadius: 4,
              background: theme.surface2, border: `1px solid ${theme.border}`,
            }}>⌘K</span>
          )}
        </div>

        {/* Filter chips + sort */}
        <div style={{
          marginTop: 14, display: 'flex', alignItems: 'center',
          justifyContent: 'space-between', gap: 8,
        }}>
          <div style={{ display: 'flex', gap: 6 }}>
            {['All', 'Pinned', 'Recent'].map(f => (
              <button key={f} onClick={() => setFilter(f)} style={{
                all: 'unset', cursor: 'pointer',
                fontFamily: FONT_STACK, fontSize: 13, fontWeight: 500,
                letterSpacing: -0.1,
                padding: '6px 12px', borderRadius: 9,
                color: filter === f ? '#fff' : theme.text2,
                background: filter === f ? theme.violet : 'transparent',
                border: filter === f ? 'none' : `1px solid ${theme.border}`,
                transition: 'all 160ms ease',
              }}>
                {f}
                {f === 'Pinned' && <span style={{
                  marginLeft: 5, opacity: filter===f ? 0.85 : 0.6,
                  fontVariantNumeric: 'tabular-nums',
                }}>
                  {notes.filter(n => n.pinned && !n.archived).length}
                </span>}
              </button>
            ))}
          </div>
          <div style={{ position: 'relative' }}>
            <button onClick={() => setSortOpen(s => !s)} style={{
              all: 'unset', cursor: 'pointer', display: 'inline-flex',
              alignItems: 'center', gap: 4,
              padding: '6px 10px', borderRadius: 9,
              border: `1px solid ${theme.border}`,
              color: theme.text2, fontSize: 13, fontWeight: 500,
            }}>
              <IconSort size={14} stroke={theme.text2}/>
              {sort}
              <IconChevronDown size={14} stroke={theme.text3}/>
            </button>
            {sortOpen && (
              <div style={{
                position: 'absolute', right: 0, top: 'calc(100% + 6px)',
                background: theme.surface, border: `1px solid ${theme.border}`,
                borderRadius: 12, padding: 4, minWidth: 160,
                boxShadow: '0 12px 32px rgba(20,10,40,0.12), 0 2px 8px rgba(20,10,40,0.06)',
                zIndex: 30,
              }}>
                {['Updated', 'Created', 'Title (A–Z)', 'Tag'].map(s => (
                  <button key={s} onClick={() => { setSort(s); setSortOpen(false); }} style={{
                    all: 'unset', cursor: 'pointer', display: 'flex',
                    alignItems: 'center', justifyContent: 'space-between',
                    padding: '8px 10px', borderRadius: 8,
                    fontSize: 13, color: theme.text, width: '100%',
                    boxSizing: 'border-box',
                    background: sort === s ? theme.violetSoft : 'transparent',
                  }}>
                    {s}
                    {sort === s && <IconCheck size={14} stroke={theme.violet}/>}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* ── Multi-select bar ─────────────── */}
      {selectMode && (
        <div style={{
          margin: '16px 20px 0', padding: '10px 12px',
          background: theme.violetSoft, borderRadius: 12,
          border: `1px solid ${theme.violetSoft2}`,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <div style={{ fontSize: 13, fontWeight: 500, color: theme.violetInk }}>
            {selected.size} selected
          </div>
          <div style={{ display: 'flex', gap: 4 }}>
            <SmallAction onClick={pinMany} theme={theme} icon={<IconPin size={15}/>} label="Pin"/>
            <SmallAction onClick={removeMany} theme={theme} icon={<IconArchive size={15}/>} label="Archive"/>
            <SmallAction onClick={removeMany} theme={theme} icon={<IconTrash size={15}/>} label="Delete" danger/>
          </div>
        </div>
      )}

      {/* ── Content ──────────────────────── */}
      <div style={{ padding: '22px 20px 0' }}>
        {visible.length === 0 ? (
          <EmptyState theme={theme} query={query} onCreate={onOpenCompose}/>
        ) : (
          <>
            {pinned.length > 0 && (
              <SectionHeader theme={theme} label="Pinned" count={pinned.length} icon={<IconPinFilled size={12} stroke={theme.violet}/>}/>
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: rowGap, marginBottom: 26 }}>
              {pinned.map(n => (
                <NoteCard key={n.id} note={n} theme={theme} radius={radius} cardPad={cardPad}
                          tagStyle={tagStyle} selectMode={selectMode}
                          selected={selected.has(n.id)} onSelect={() => toggleSel(n.id)}
                          onPin={() => togglePin(n.id)} onArchive={() => archive(n.id)}
                          onOpen={() => !selectMode && onOpenNote?.(n)}
                          swipeOpen={swipeId === n.id} onSwipe={(o) => setSwipeId(o ? n.id : null)} />
              ))}
            </div>

            {rest.length > 0 && (
              <SectionHeader theme={theme} label="All notes" count={rest.length} />
            )}
            <div style={{ display: 'flex', flexDirection: 'column', gap: rowGap }}>
              {rest.map(n => (
                <NoteCard key={n.id} note={n} theme={theme} radius={radius} cardPad={cardPad}
                          tagStyle={tagStyle} selectMode={selectMode}
                          selected={selected.has(n.id)} onSelect={() => toggleSel(n.id)}
                          onPin={() => togglePin(n.id)} onArchive={() => archive(n.id)}
                          onOpen={() => !selectMode && onOpenNote?.(n)}
                          swipeOpen={swipeId === n.id} onSwipe={(o) => setSwipeId(o ? n.id : null)} />
              ))}
            </div>
          </>
        )}
      </div>

      {/* ── FAB ──────────────────────────── */}
      {!selectMode && <FAB theme={theme} style={fabStyle} onClick={onOpenCompose}/>}

      {/* ── Toast ────────────────────────── */}
      {toast && (
        <div style={{
          position: 'absolute', bottom: 110, left: '50%',
          transform: 'translateX(-50%)',
          background: theme.dark ? '#2A2138' : '#1B1427',
          color: '#fff', fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
          padding: '10px 14px', borderRadius: 999,
          display: 'inline-flex', alignItems: 'center', gap: 10,
          boxShadow: '0 10px 30px rgba(20,10,40,0.22)',
          animation: 'toastIn 240ms cubic-bezier(.2,.9,.2,1)',
          zIndex: 40, whiteSpace: 'nowrap',
        }}>
          Note archived
          <button onClick={() => {
            setNotes(ns => ns.map(n => n.id === toast.id ? { ...n, archived: false } : n));
            setToast(null);
          }} style={{
            all: 'unset', cursor: 'pointer', color: theme.violet,
            fontWeight: 600,
          }}>Undo</button>
        </div>
      )}
    </div>
  );
}

// ──────────────────────────────────────
// Section header
// ──────────────────────────────────────
function SectionHeader({ theme, label, count, icon }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 7,
      marginBottom: 10, paddingLeft: 2,
    }}>
      {icon}
      <div style={{
        fontSize: 11.5, fontWeight: 600, letterSpacing: 0.6,
        color: theme.text3, textTransform: 'uppercase',
      }}>{label}</div>
      <div style={{
        fontSize: 11.5, fontWeight: 500, color: theme.text4,
        fontVariantNumeric: 'tabular-nums',
      }}>{count}</div>
      <div style={{ flex: 1, height: 1, background: theme.border, marginLeft: 4 }}/>
    </div>
  );
}

// ──────────────────────────────────────
// Note card — with swipe-to-archive
// ──────────────────────────────────────
function NoteCard({ note, theme, radius, cardPad, tagStyle, selectMode, selected,
                    onSelect, onPin, onArchive, onOpen, swipeOpen, onSwipe }) {
  const [dx, setDx] = React.useState(0);
  const [dragging, setDragging] = React.useState(false);
  const startX = React.useRef(0);
  const lastDx = React.useRef(0);

  const maxSwipe = 140;
  const threshold = 72;

  const onPointerDown = (e) => {
    if (selectMode) return;
    startX.current = e.clientX;
    lastDx.current = swipeOpen ? -maxSwipe : 0;
    setDragging(true);
    e.currentTarget.setPointerCapture?.(e.pointerId);
  };
  const onPointerMove = (e) => {
    if (!dragging) return;
    const d = Math.min(0, Math.max(-maxSwipe - 20, e.clientX - startX.current + lastDx.current));
    setDx(d);
  };
  const onPointerUp = () => {
    if (!dragging) return;
    setDragging(false);
    if (dx < -threshold) { setDx(-maxSwipe); onSwipe(true); }
    else { setDx(0); onSwipe(false); }
  };

  React.useEffect(() => {
    if (!swipeOpen && dx !== 0 && !dragging) setDx(0);
  }, [swipeOpen]);

  const effectiveDx = dragging ? dx : (swipeOpen ? -maxSwipe : 0);

  return (
    <div style={{ position: 'relative', userSelect: 'none' }}>
      {/* swipe actions (revealed beneath) */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: radius,
        display: 'flex', justifyContent: 'flex-end',
        background: 'linear-gradient(90deg, transparent 30%, #FEE2E2 50%, #FCA5A5 100%)',
        overflow: 'hidden',
      }}>
        <button onClick={onArchive} style={{
          all: 'unset', cursor: 'pointer', width: 140,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          color: '#7F1D1D', fontSize: 13, fontWeight: 600, letterSpacing: -0.1,
        }}>
          <IconArchive size={18}/> Archive
        </button>
      </div>

      {/* actual card */}
      <div
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onClick={() => { if (!dragging && effectiveDx === 0) { selectMode ? onSelect() : onOpen(); } }}
        style={{
          position: 'relative',
          background: theme.surface, border: `1px solid ${theme.border}`,
          borderRadius: radius, padding: cardPad,
          boxShadow: '0 1px 2px rgba(20,10,40,0.02)',
          transform: `translateX(${effectiveDx}px)`,
          transition: dragging ? 'none' : 'transform 280ms cubic-bezier(.2,.9,.2,1)',
          cursor: selectMode ? 'pointer' : 'default',
          outline: selected ? `2px solid ${theme.violet}` : 'none',
          outlineOffset: -1,
        }}>
        <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
          {selectMode && (
            <div style={{
              width: 20, height: 20, borderRadius: 999,
              border: `1.5px solid ${selected ? theme.violet : theme.borderStrong}`,
              background: selected ? theme.violet : 'transparent',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0, marginTop: 2,
            }}>
              {selected && <IconCheck size={12} stroke="#fff"/>}
            </div>
          )}
          <div style={{ flex: 1, minWidth: 0 }}>
            {/* top row: title + pin */}
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
              <div style={{
                flex: 1, minWidth: 0,
                fontSize: 15.5, fontWeight: 600, lineHeight: 1.28,
                letterSpacing: -0.32, color: theme.text,
                overflow: 'hidden', textOverflow: 'ellipsis',
                display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
              }}>{note.title}</div>
              <button onClick={(e) => { e.stopPropagation(); onPin(); }} style={{
                all: 'unset', cursor: 'pointer', padding: 2,
                color: note.pinned ? theme.violet : theme.text4,
                flexShrink: 0, marginTop: -1,
              }}>
                {note.pinned ? <IconPinFilled size={14}/> : <IconPin size={14}/>}
              </button>
            </div>

            {/* preview */}
            <div style={{
              marginTop: 4,
              fontSize: 13.25, lineHeight: 1.45,
              letterSpacing: -0.15, color: theme.text3,
              display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}>{note.preview}</div>

            {/* footer: tags + time */}
            <div style={{
              marginTop: 10, display: 'flex',
              alignItems: 'center', justifyContent: 'space-between', gap: 8,
            }}>
              <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
                {note.tags.map(t => (
                  <TagPill key={t} name={t} theme={theme} small style={tagStyle}/>
                ))}
              </div>
              <div style={{
                fontSize: 11, color: theme.text4, fontVariantNumeric: 'tabular-nums',
                fontFamily: FONT_STACK, letterSpacing: -0.1, flexShrink: 0,
              }}>{note.updated}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────
// FAB — 3 styles
// ──────────────────────────────────────
function FAB({ theme, style = 'pillLabel', onClick }) {
  if (style === 'bottomBar') {
    return (
      <div style={{
        position: 'absolute', bottom: 32, left: 16, right: 16,
        background: theme.dark ? 'rgba(30,25,40,0.72)' : 'rgba(255,255,255,0.72)',
        backdropFilter: 'blur(20px) saturate(180%)',
        WebkitBackdropFilter: 'blur(20px) saturate(180%)',
        border: `1px solid ${theme.border}`, borderRadius: 20,
        padding: 6, display: 'flex', alignItems: 'center', gap: 6,
        boxShadow: '0 10px 30px rgba(60,30,120,0.12), 0 2px 8px rgba(60,30,120,0.06)',
        zIndex: 30,
      }}>
        <button onClick={onClick} style={{
          all: 'unset', flex: 1, cursor: 'pointer',
          background: `linear-gradient(135deg, ${theme.violet}, ${theme.violetDeep})`,
          color: '#fff', borderRadius: 14, padding: '12px 16px',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          fontSize: 15, fontWeight: 600, letterSpacing: -0.2,
          boxShadow: '0 4px 12px rgba(124,92,245,0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
        }}>
          <IconPlus size={18} strokeWidth={2.4}/> New note
        </button>
        <button style={{
          all: 'unset', cursor: 'pointer',
          width: 44, height: 44, borderRadius: 14,
          background: theme.dark ? 'rgba(255,255,255,0.08)' : 'rgba(28,20,40,0.05)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: theme.text2,
        }}><IconMic size={18}/></button>
      </div>
    );
  }
  if (style === 'orb') {
    return (
      <button onClick={onClick} style={{
        all: 'unset', position: 'absolute', bottom: 38, right: 22,
        width: 60, height: 60, borderRadius: 30, cursor: 'pointer',
        background: `radial-gradient(circle at 30% 25%, #D7C6FF, ${theme.violetDeep} 75%)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#fff',
        boxShadow: '0 0 0 6px rgba(167,139,250,0.12), 0 12px 30px rgba(124,92,245,0.4), inset 0 2px 0 rgba(255,255,255,0.35)',
        zIndex: 30,
      }}>
        <IconPlus size={26} strokeWidth={2.4}/>
      </button>
    );
  }
  // default: pillLabel — elongated pill, centered, with label
  return (
    <button onClick={onClick} style={{
      all: 'unset', position: 'absolute', bottom: 36, left: '50%',
      transform: 'translateX(-50%)', cursor: 'pointer',
      background: `linear-gradient(135deg, ${theme.violet} 0%, ${theme.violetDeep} 100%)`,
      color: '#fff', borderRadius: 999, padding: '13px 22px',
      display: 'flex', alignItems: 'center', gap: 9,
      fontFamily: FONT_STACK, fontSize: 15, fontWeight: 600, letterSpacing: -0.25,
      boxShadow: '0 10px 30px rgba(124,92,245,0.42), 0 2px 6px rgba(124,92,245,0.2), inset 0 1px 0 rgba(255,255,255,0.28)',
      zIndex: 30,
    }}>
      <div style={{
        width: 22, height: 22, borderRadius: 11,
        background: 'rgba(255,255,255,0.22)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.2)',
      }}>
        <IconPlus size={14} strokeWidth={2.8}/>
      </div>
      New note
    </button>
  );
}

// ──────────────────────────────────────
// Small helpers
// ──────────────────────────────────────
function IconButton({ children, theme, onClick }) {
  return (
    <button onClick={onClick} style={{
      all: 'unset', cursor: 'pointer',
      width: 32, height: 32, borderRadius: 999,
      background: theme.surface, border: `1px solid ${theme.border}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: theme.text2,
    }}>{children}</button>
  );
}

function SmallAction({ onClick, theme, icon, label, danger }) {
  return (
    <button onClick={onClick} style={{
      all: 'unset', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '5px 10px', borderRadius: 8,
      color: danger ? '#B91C1C' : theme.violetInk,
      fontSize: 12.5, fontWeight: 600, letterSpacing: -0.1,
    }}>{icon}{label}</button>
  );
}

function EmptyState({ theme, query, onCreate }) {
  return (
    <div style={{
      padding: '60px 10px', textAlign: 'center',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16,
    }}>
      {/* Illustration: stacked cards, subtle */}
      <div style={{ position: 'relative', width: 104, height: 96 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{
            position: 'absolute', left: `${8 + i*8}px`, top: `${6 + i*6}px`,
            width: 80, height: 68, borderRadius: 10,
            background: i === 2 ? theme.surface : (theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(27,20,39,0.04)'),
            border: `1px solid ${theme.border}`,
            transform: `rotate(${-6 + i*5}deg)`,
          }}>
            {i === 2 && (
              <>
                <div style={{ margin: '12px 12px 4px', height: 6, borderRadius: 3, background: theme.violetSoft2, width: '60%'}}/>
                <div style={{ margin: '0 12px 4px', height: 4, borderRadius: 2, background: theme.border, width: '80%'}}/>
                <div style={{ margin: '0 12px 4px', height: 4, borderRadius: 2, background: theme.border, width: '50%'}}/>
              </>
            )}
          </div>
        ))}
      </div>
      <div>
        <div style={{
          fontFamily: FONT_DISPLAY, fontSize: 24, letterSpacing: -0.5,
          color: theme.text, marginBottom: 4,
        }}>
          {query ? `No notes match "${query}"` : 'A blank page awaits.'}
        </div>
        <div style={{ fontSize: 13.5, color: theme.text3, letterSpacing: -0.1, maxWidth: 260 }}>
          {query ? 'Try a different search, or clear filters to see everything.'
                 : 'Capture a thought, a lecture, a link — Notely syncs it across your devices.'}
        </div>
      </div>
      {!query && (
        <button onClick={onCreate} style={{
          all: 'unset', cursor: 'pointer', marginTop: 4,
          background: theme.violet, color: '#fff',
          fontSize: 14, fontWeight: 600, letterSpacing: -0.2,
          padding: '10px 18px', borderRadius: 12,
          display: 'inline-flex', alignItems: 'center', gap: 6,
          boxShadow: '0 6px 14px rgba(124,92,245,0.3)',
        }}>
          <IconPlus size={16} strokeWidth={2.4}/> Start writing
        </button>
      )}
    </div>
  );
}

Object.assign(window, { VariantEditorial, NoteCard, FAB, SectionHeader, EmptyState });
