# Content editor — inline sub-resource creation from dropdown

**Added:** 2026-05-21
**Summary:** Let a resource-ref dropdown create a new concrete sub-resource inline and wire it in, with breadcrumb navigation.

## Notes
When a field expects a resource ref (e.g. a weapon's `attacks` array, or an attack's `effects` array), the dropdown currently only lets you pick an existing file. The missing flow is: click "new" in that dropdown, choose the concrete type (e.g. `AttackData`, `DamageEffect`), give it a name/path, and it's created and immediately wired in. Pairs naturally with a breadcrumb bar — if you're authoring a weapon and create a new attack inline, you should be able to navigate into that attack's form, then navigate back up to the weapon. Without the breadcrumb, you'd have to find the new file in the sidebar to finish filling it in, which breaks the authoring flow for a weapon that needs two or three new attacks at once.
