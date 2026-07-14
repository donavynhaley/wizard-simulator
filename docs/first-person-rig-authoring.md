# First-Person Rig Authoring

The player is composed from [`game/player/player.tscn`](../game/player/player.tscn), [`game/player/body/wizard_body.tscn`](../game/player/body/wizard_body.tscn), and [`game/player/viewmodel/first_person_viewmodel.tscn`](../game/player/viewmodel/first_person_viewmodel.tscn).
The root scene owns movement, the gameplay camera, and interaction wiring.
The body scene owns the imported wizard model and physical beard, while the viewmodel scene owns arm pose controls and first-person animation players.

`BodyRig/WizardModel` is the player's only wizard model instance.
It is anchored to the player instead of the camera, preserving connected shoulders, a physical torso, the hat, and the beard.
The first-person mesh retains the hat, beard, robe, shoulders, and arms.
Triangles weighted to the head and neck are removed because those surfaces would surround the camera and intersect its near plane.
The loose `DEF-FOREARM-HANG` drape is also removed from the first-person mesh so raising an arm cannot cover the camera, while the fitted sleeve, shoulder, arm, and hand remain visible.
The `LeftArmPose` and `RightArmPose` controls move the corresponding shoulder bones independently without duplicating the wizard model.
After those authored poses are applied, a `TwoBoneIK3D` modifier moves each wrist toward its complete camera-local transform.
The solver keeps the hands at a stable screen position and depth while preserving fixed bone lengths and connected shoulders.
The elbow pole follows the authored forearm pose in the same camera-local frame, so idle, grab, hold, release, and beard-lift animations retain their intended bends.
A following `CopyTransformModifier3D` restores each authored hand's camera-local orientation without changing its IK position.

The authored eye alignment is controlled by the `Head` and `Camera3D` transforms in `player.tscn` plus the `BodyRig/WizardModel` transform in `wizard_body.tscn`.
The camera uses a `0.03` meter near plane and the player's vertical look is limited to 75 degrees so the view cannot rotate into the hat crown or torso.
The model is positioned so the brim is only a thin accent at the top of the neutral view and the beard enters the frame when looking down.
Looking up and down rotates the connected arms procedurally so the resting hands remain at the lower edges of the frame.
After the screen-lock threshold, the hidden head bone tilts the hat with the camera so the brim settles into a stable screen position.
The hand target and elbow pole markers are authored under `Head/Camera3D/Viewmodel/CameraLocalArmTargets`.
The `camera_hand_horizontal_scale` property pulls the original wide arm pose inward far enough to keep both wrist targets reachable throughout vertical look.
The `camera_hand_vertical_offset` property keeps the resting fingertips in the lower third instead of crowding the crosshair.
The hat values remain editable on `Head/Camera3D/Viewmodel/FirstPersonWizardRig` as `hat_screen_lock_start_pitch_degrees` and `hat_screen_lock_strength`.

## Preview the First-Person Camera

1. Open `game/player/player.tscn`.
2. Select `Head/Camera3D`.
3. Enable the camera preview in the 3D viewport.
4. Keep that preview visible while scrubbing or playing an animation in the Animation panel.

Because this is the gameplay camera, its preview always matches the runtime field of view and player-relative composition.

## Animate the Full Skeleton

1. Open `game/player/body/wizard_body.tscn`.
2. Expand `WizardModel/RootNode/Armature` and select `Skeleton3D`.
3. Select `FullBodyAnimationPlayer` and create or choose a clip in the Animation panel.
4. Return to `Skeleton3D`, enable bone editing in the 3D toolbar, and select the bone you want to pose.
5. Move or rotate the bone with the viewport gizmo and insert its pose key into the active clip.

The body scene instances the imported `WizardModel` without persisting modified copies of its internal children.
`FullBodyAnimationPlayer` is owned by `wizard_body.tscn`, so imported assets can be replaced without losing authored player animations.
The procedural hand and beard controls do not overwrite bone poses while working in the editor unless `preview_control_rig_in_editor` is enabled on their controller.

## Edit Idle, Grab, Hold, and Release

1. Select `Head/Camera3D/Viewmodel/FirstPersonWizardRig/GraspAnimationPlayer`.
2. Choose `idle`, `grab`, `hold`, or `release` in the Animation panel.
3. Move the timeline to the frame you want to change.
4. Select `ArmModels/RightArmPose` and move or rotate the arm with the 3D viewport gizmo.
5. Select a marker under `HandControls` and rotate it to pose the visible wrist, thumb, or fingers.
6. Insert a key with Godot's key button or enable Auto Key while posing.

The hand controls are `Wrist`, `Thumb01`, `Thumb02`, `Thumb03`, `Finger01`, `Finger02`, and `Finger03`.
They are spatial controls positioned over their corresponding bones by the editor tool script.
Their rotations are applied to the real wizard skeleton immediately, so the model remains visible while posing and scrubbing.

The looping `idle` animation keeps both open hands at the lower edges of the first-person view and gives them subtle independent motion.
The `RESET` animation remains the neutral editor reset pose.
The `grab` animation reaches into the manipulation pose.
The `hold` animation loops while an object floats above the hand.
The `release` animation returns every keyed control to the visible idle pose and automatically resumes its loop.

## Edit the Beard Inventory Motion

The imported wizard model does not contain beard geometry; its `DEF-SCARF` bones control the red collar.
The visible beard is a flattened, tapered four-segment low-poly mesh authored directly under `BeardAnchor/Beard` in `wizard_body.tscn`.
The four nested controls make the beard flexible without creating runtime geometry.
The beard remains anchored to the player independently of camera pitch and naturally enters the view when the player looks down.

Select `BeardAnchor/Beard/BeardAnimationPlayer` in `wizard_body.tscn` to edit the beard's `lift` and `lower` clips.
Select `BeardRoot`, `Joint02`, `Joint03`, or `Joint04` and manipulate those controls directly in the 3D viewport.

Select `Head/Camera3D/Viewmodel/FirstPersonWizardRig/BeardInteractionAnimationPlayer` to edit the left arm that reaches up with the beard.
The beard and arm clips share the same durations so they can be scrubbed side by side.

`BeardInventoryAnchor` contains three marker slots for future spell-card inventory presentation.
While looking down, holding `B` lifts the beard and left hand, and releasing `B` lowers them.
