# A Promise Kept 0.2.0

The redesigned game starts at `Game/main.tscn`. The original music files are reused without modification. Legacy scenes remain in source for reference, but are not shipped in the redesigned exports.

Rin/Asami and the protagonist are both 17-year-old high-school classmates. The campaign takes place during spring recess. See `CHARACTER_DIRECTION.md` for the updated design and continuity.

## Editing story with Dialogic

The 24 relationship scenes are genuine Dialogic timelines in `Game/Timelines/`. Open the Dialogic editor in Godot to edit their dialogue. Keep the `line_N` labels and `line:N:Speaker:protected` signals: they control save checkpoints, speaker labels, and protected skipping. Routine lines can use `routine` in place of `protected`.

`Game/dialogue.gd` supplies the cinematic layout. Dialogic executes the timeline, reveals the text, records history, advances events and performs held auto-skip. The custom layout owns conversation teardown and disables Dialogic's default ending timeline, which would otherwise create the retired VN layout just to clear it. The final response buttons commit one relationship transaction through Campaign, preventing duplicate rewards. Their definitions live in `Game/Data/campaign.json`.

`tools/build_campaign_content.py` is the original content authoring source. Running it regenerates both JSON and the 24 timelines, replacing manual changes to those generated files. Ordinary Godot imports and builds do not regenerate content.

## State, saving and legacy import

Campaign is the authority for the wallet, equipment, quest counters, relationship meters, clock, activities, memories and endings. The old autoload names remain available so historical scenes still parse; redesigned scenes do not use their independent balances or save files.

New version-3 saves live in `user://campaign/`. Nine manual slots and the autosave share the same snapshot schema. Writes use a temporary file and retain a previous backup. A saved expedition retains position, defeated enemies, gathered nodes and opened chests. Dialogue resumes at its current line.

Legacy imports are explicit from the title's Save stories screen. They back up the original file, require an empty new slot, retain health/affection/currency, and begin the expanded story on day one. Starting a new story does not delete legacy saves or manual slots.

## Controls

WASD/arrows move; left mouse attacks; right mouse uses the weapon skill; Space dodges; F interacts; R drinks restorative tea; B recalls; I opens the pack; J opens the journal; Escape opens or closes menus. One weapon is equipped through inventory. Settings support keyboard remapping and three camera distances.

Enter or Space reveals/advances dialogue. Holding for 0.35 seconds skips ordinary dialogue using Dialogic auto-skip. Protected lines and choices require fresh manual input. Touch uses a joystick, four combat/context buttons and the menu for utilities.

## Local illustration studio

`tools/setup_art_studio.py` installs an isolated Python 3.10.11 environment and AUTOMATIC1111 under the ignored `.private/art-studio/` directory. AOM3A1B is downloaded from the original WarriorMama777/OrangeMixs repository, with SHA256 verified against `5493a0ec491f5961dbdc1c861404088a6ae9bd4007f6a3a7c5dee8789cdc1361`.

The original Stability-AI code repository is unavailable, so the launcher uses the maintained `w-e-w/stablediffusion` fork at the same required commit. Legacy packaging dependencies are pinned only inside the private environment. The API binds locally on port 7861; no public sharing option is enabled.

`tools/prepare_controlnet.py` installs the official Mikubill extension and lllyasviel's SD 1.5 OpenPose weights. All models, environments and intermediate images stay outside Git and exported game builds. Final PNGs and generation metadata belong in `Game/Art/`.

Generate the current character set with the studio Python and `tools/regenerate_student_art.py`. That workflow supersedes the earlier mature-character candidates. It uses local AOM3, pose guidance, inpainting for the alternate outfit, and local anime foreground segmentation for transparent overlays. The private compatibility requirements keep NumPy, MediaPipe, OpenCV and ONNX consistent; protobuf uses the compatible 3.20.3 patch release.

`tools/review_anatomy.py` creates enlarged private hand-review crops. `tools/repair_anatomy.py` creates masked hand candidates and verifies the approved face pixels remain unchanged before allowing a reviewed candidate to replace the final PNG. The seated correction is recorded in its adjacent asset metadata. Cooking, reading and bed-pose illustrations were withdrawn; only seated and standing poses remain active. Automated file validation does not replace visual anatomy review.

The home uses the muted colored room and illustrations with compact status panels; no black-and-white material is applied. Seated Rin is aligned to the sofa cushion, with the old chair ends removed and a subtle contact shadow. Clicking her hides the room overlay and shows a much closer waist-up talking portrait for the whole Dialogic conversation. Closing dialogue restores the seated view and saves its completion, without a stand-up animation. Activities use text and choices rather than additional action poses.

`tools/generate_closeup_revision.py` produces review candidates using local AOM3 and the original gsdf EasyNegativeV2 SafeTensors embedding. The embedding hash is checked before loading, and source/license details are recorded in the final image metadata. Candidates remain private until visual review; negative embeddings cannot guarantee correct anatomy.

## Verification

`tools/protect_redesign_inputs.py` preserves initial legacy saves and verifies all eight soundtrack hashes. `tools/check_redesign.ps1`, `-Integration`, and `-Runtime` create a unique isolated application identity and remove their temporary override on exit. Never run the suites against a real player profile.

Campaign tests cover all five ending conditions, the full calendar route, duplicate-reward prevention, wallet consistency, equipment state, save round-trips and legacy preservation. Integration tests exercise actual Dialogic protection, attack damage, hit immunity, ranged aim, equipment visuals, pause behavior, recall and defeat.

Playtime is a design target and must be measured through real playtesting; automated progression is not a duration measurement.
