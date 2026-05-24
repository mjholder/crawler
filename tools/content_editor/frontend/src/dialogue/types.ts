export interface DialogueChoice {
  text: string;
  next: string;
}

export interface DialogueConsequence {
  action: string;
  value: string;
}

export interface DialogueRewards {
  experience: number;
  gold: number;
}

export interface DialogueNode {
  speaker: string | null;
  text: string;
  consequence: DialogueConsequence | null;
  choices: DialogueChoice[];
  rewards?: DialogueRewards;
}

export interface DialogueJson {
  name: string;
  nodes: Record<string, DialogueNode>;
}

export type PositionMap = Record<string, { x: number; y: number }>;
