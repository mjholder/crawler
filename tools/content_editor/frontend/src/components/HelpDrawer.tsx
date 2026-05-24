import { useEffect, useRef, useState } from "react";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { getSection, fullGuide } from "../help/sections.js";

interface Props {
  anchor: string;
  onClose: () => void;
  onNavigate: (anchor: string) => void;
}

export function HelpDrawer({ anchor, onClose, onNavigate }: Props) {
  const [showFull, setShowFull] = useState(false);
  const bodyRef = useRef<HTMLDivElement>(null);

  // Close on Escape.
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [onClose]);

  // When showing the full guide, scroll to the requested anchor.
  useEffect(() => {
    if (!showFull || !bodyRef.current) return;
    const el = bodyRef.current.querySelector(`[data-anchor="${anchor}"]`);
    if (el) el.scrollIntoView({ block: "start" });
  }, [showFull, anchor]);

  // Intercept internal #anchor link clicks — navigate within the drawer.
  function handleClick(e: React.MouseEvent<HTMLDivElement>) {
    const target = e.target as HTMLElement;
    const a = target.closest("a");
    if (!a) return;
    const href = a.getAttribute("href");
    if (!href?.startsWith("#")) return;
    e.preventDefault();
    const dest = href.slice(1);
    if (showFull) {
      const el = bodyRef.current?.querySelector(`[data-anchor="${dest}"]`);
      if (el) el.scrollIntoView({ block: "start" });
    } else {
      onNavigate(dest);
    }
  }

  const section = getSection(anchor);
  const content = showFull ? fullGuide : (section?.markdown ?? `*No help found for "${anchor}".*`);
  const title = showFull ? "User Guide" : (section?.title ?? anchor);

  return (
    <>
      {/* Backdrop — click to close */}
      <div style={s.backdrop} onClick={onClose} />

      <div style={s.drawer}>
        {/* Header */}
        <div style={s.header}>
          <span style={s.title}>{title}</span>
          <div style={s.headerRight}>
            <button
              style={s.toggleBtn}
              onClick={() => setShowFull((v) => !v)}
              title={showFull ? "Back to section" : "Read full guide"}
            >
              {showFull ? "← Section" : "Full guide ↗"}
            </button>
            <button style={s.closeBtn} onClick={onClose} title="Close help">×</button>
          </div>
        </div>

        {/* Body */}
        <div ref={bodyRef} style={s.body} className="help-drawer-body" onClick={handleClick}>
          <style>{tableStyles}</style>
          {showFull ? (
            <FullGuide content={content} currentAnchor={anchor} />
          ) : (
            <ReactMarkdown remarkPlugins={[remarkGfm]}>
              {content}
            </ReactMarkdown>
          )}
        </div>
      </div>
    </>
  );
}

// Full guide with anchor markers injected before each heading.
function FullGuide({ content, currentAnchor }: { content: string; currentAnchor: string }) {
  // Pre-process: inject `<a data-anchor="slug">` markers before each heading.
  // We do this by splitting and rendering each section individually.
  const lines = content.split("\n");
  const chunks: Array<{ anchor: string; lines: string[] }> = [];
  let current: { anchor: string; lines: string[] } | null = null;

  function slugify(heading: string): string {
    const explicit = heading.match(/\{#([a-z0-9-]+)\}/);
    if (explicit) return explicit[1];
    return heading.toLowerCase().replace(/[^\w\s-]/g, "").trim().replace(/\s+/g, "-");
  }

  for (const line of lines) {
    const m = line.match(/^(#{2,4}) (.+)/);
    if (m) {
      if (current) chunks.push(current);
      current = { anchor: slugify(m[2]), lines: [line] };
    } else {
      if (current) current.lines.push(line);
    }
  }
  if (current) chunks.push(current);

  return (
    <>
      {chunks.map((chunk) => (
        <div
          key={chunk.anchor}
          data-anchor={chunk.anchor}
          style={chunk.anchor === currentAnchor ? s.highlighted : undefined}
        >
          <ReactMarkdown remarkPlugins={[remarkGfm]}>
            {chunk.lines.join("\n")}
          </ReactMarkdown>
        </div>
      ))}
    </>
  );
}

const tableStyles = `
  .help-drawer-body table {
    border-collapse: collapse;
    width: 100%;
    font-size: 12px;
    margin: 8px 0;
  }
  .help-drawer-body th,
  .help-drawer-body td {
    border: 1px solid #333;
    padding: 5px 8px;
    text-align: left;
    vertical-align: top;
  }
  .help-drawer-body th {
    background: #1e1e2e;
    color: #aaa;
    font-weight: 600;
  }
  .help-drawer-body tr:nth-child(even) td {
    background: #161620;
  }
  .help-drawer-body code {
    background: #222;
    border: 1px solid #333;
    border-radius: 3px;
    padding: 1px 4px;
    font-size: 11px;
    font-family: monospace;
    color: #c9c;
  }
  .help-drawer-body pre {
    background: #1a1a2a;
    border: 1px solid #333;
    border-radius: 4px;
    padding: 10px;
    overflow-x: auto;
    font-size: 11px;
  }
  .help-drawer-body pre code {
    background: none;
    border: none;
    padding: 0;
    color: #cdc;
  }
  .help-drawer-body a {
    color: #7af;
    text-decoration: none;
  }
  .help-drawer-body a:hover {
    text-decoration: underline;
  }
  .help-drawer-body h2, .help-drawer-body h3 {
    color: #eee;
    margin: 16px 0 6px;
    font-size: 14px;
  }
  .help-drawer-body h4 {
    color: #ccc;
    margin: 12px 0 4px;
    font-size: 13px;
  }
  .help-drawer-body p {
    margin: 6px 0;
    line-height: 1.5;
    color: #ccc;
    font-size: 13px;
  }
  .help-drawer-body ul, .help-drawer-body ol {
    margin: 4px 0;
    padding-left: 20px;
    font-size: 13px;
    color: #ccc;
    line-height: 1.6;
  }
  .help-drawer-body hr {
    border: none;
    border-top: 1px solid #2a2a2a;
    margin: 12px 0;
  }
`;

const s: Record<string, React.CSSProperties> = {
  backdrop: {
    position: "fixed",
    inset: 0,
    zIndex: 100,
  },
  drawer: {
    position: "fixed",
    top: 0,
    right: 0,
    bottom: 0,
    width: "min(44vw, 620px)",
    display: "flex",
    flexDirection: "column",
    background: "#111",
    borderLeft: "1px solid #2a2a2a",
    zIndex: 101,
    boxShadow: "-4px 0 24px rgba(0,0,0,0.6)",
  },
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "8px 12px",
    background: "#161616",
    borderBottom: "1px solid #2a2a2a",
    flexShrink: 0,
    gap: 8,
  },
  title: {
    fontSize: 13,
    fontWeight: 600,
    color: "#ddd",
    overflow: "hidden",
    textOverflow: "ellipsis",
    whiteSpace: "nowrap",
    flex: 1,
  },
  headerRight: {
    display: "flex",
    gap: 6,
    alignItems: "center",
    flexShrink: 0,
  },
  toggleBtn: {
    padding: "3px 8px",
    background: "none",
    border: "1px solid #333",
    color: "#7af",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 11,
  },
  closeBtn: {
    padding: "3px 8px",
    background: "none",
    border: "1px solid #333",
    color: "#888",
    cursor: "pointer",
    borderRadius: 3,
    fontSize: 14,
    lineHeight: 1,
  },
  body: {
    flex: 1,
    overflowY: "auto",
    padding: "14px 16px",
    // class applied to scope the table styles
    // (applied via the className workaround below)
  },
  highlighted: {
    background: "#1a1a2a",
    borderLeft: "2px solid #446",
    paddingLeft: 8,
    marginLeft: -8,
    borderRadius: 2,
  },
};
