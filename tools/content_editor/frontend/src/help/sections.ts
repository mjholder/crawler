import guideRaw from "../../../docs/USER_GUIDE.md?raw";

export interface Section {
  anchor: string;
  title: string;
  level: number;
  /** The heading line + body content, ready to render. */
  markdown: string;
}

function slugify(heading: string): string {
  // Strip explicit {#anchor} markers and return them directly.
  const explicit = heading.match(/\{#([a-z0-9-]+)\}/);
  if (explicit) return explicit[1];
  return heading
    .toLowerCase()
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/\s+/g, "-");
}

function buildSections(raw: string): Map<string, Section> {
  const lines = raw.split("\n");
  const result = new Map<string, Section>();

  // Collect heading positions: { lineIndex, level, title, anchor }
  type HeadingEntry = { idx: number; level: number; title: string; anchor: string };
  const headings: HeadingEntry[] = [];

  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(#{2,4}) (.+)/);
    if (!m) continue;
    const level = m[1].length;
    const raw_title = m[2];
    const title = raw_title.replace(/\{#[a-z0-9-]+\}/, "").trim();
    const anchor = slugify(raw_title);
    headings.push({ idx: i, level, title, anchor });
  }

  for (let h = 0; h < headings.length; h++) {
    const { idx, level, title, anchor } = headings[h];

    // Body runs to the next heading of equal-or-higher level (lower number).
    let endIdx = lines.length;
    for (let k = h + 1; k < headings.length; k++) {
      if (headings[k].level <= level) {
        endIdx = headings[k].idx;
        break;
      }
    }

    const body = lines.slice(idx + 1, endIdx).join("\n").trim();
    // Include the heading itself so the drawer has a visible title.
    const markdown = `${lines[idx]}\n\n${body}`;

    result.set(anchor, { anchor, title, level, markdown });
  }

  return result;
}

// Build once at module load time.
export const sections: Map<string, Section> = buildSections(guideRaw);
export const fullGuide: string = guideRaw;

export function getSection(anchor: string): Section | undefined {
  return sections.get(anchor);
}
