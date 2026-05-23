/**
 * CLI helper: run `npm run schema` to regenerate schema.json.
 * Called by the user when resource class @export properties change.
 */
import { refreshSchema } from "./schema.js";

await refreshSchema();
