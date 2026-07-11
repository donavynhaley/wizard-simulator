# First-Person Rig Authoring

The first-person arms, hand controls, beard, gameplay camera, and animation players are all authored in [`scenes/characters/player.tscn`](../scenes/characters/player.tscn).
This is the only editable player scene.
The wizard GLB remains an imported model asset, but there are no intermediate player, arm-rig, or beard wrapper scenes.

`BodyRig/WizardModel` is the player's only wizard model instance.
It is anchored to the player instead of the camera, so looking up and down moves naturally beneath the hat and above the beard.
The first-person mesh retains the hat, beard, robe, shoulders, and arms.
Only triangles weighted to the head and neck are removed because those surfaces would surround the camera and intersect its near plane.
The `LeftArmPose` and `RightArmPose` controls move the corresponding shoulder bones independently without duplicating the wizard model.

The authored eye alignment is controlled by the `Head`, `Camera3D`, and `BodyRig/WizardModel` transforms in `player.tscn`.
The camera uses a `0.03` meter near plane and the player's vertical look is limited to 75 degrees so the view cannot rotate into the hat crown or torso.

## Preview the First-Person Camera

1. Open `scenes/characters/player.tscn`.
2. Select `Head/Camera3D`.
3. Enable the camera preview in the 3D viewport.
4. Keep that preview visible while scrubbing or playing an animation in the Animation panel.

Because this is the gameplay camera, its preview always matches the runtime field of view and player-relative composition.

## Edit Grab, Hold, and Release

1. Select `Head/Camera3D/Viewmodel/FirstPersonWizardRig/GraspAnimationPlayer`.
2. Choose `grab`, `hold`, or `release` in the Animation panel.
3. Move the timeline to the frame you want to change.
4. Select `ArmModels/RightArmPose` and move or rotate the arm with the 3D viewport gizmo.
5. Select a marker under `HandControls` and rotate it to pose the visible wrist, thumb, or fingers.
6. Insert a key with Godot's key button or enable Auto Key while posing.

The hand controls are `Wrist`, `Thumb01`, `Thumb02`, `Thumb03`, `Finger01`, `Finger02`, and `Finger03`.
They are spatial controls positioned over their corresponding bones by the editor tool script.
Their rotations are applied to the real wizard skeleton immediately, so the model remains visible while posing and scrubbing.

The `RESET` animation defines the resting arm and open hand.
The `grab` animation reaches into the manipulation pose.
The `hold` animation loops while an object floats above the hand.
The `release` animation returns every keyed control to the resting pose.

## Edit the Beard Inventory Motion

The visible beard comes from `BodyRig/WizardModel`.
The four controls under `BodyRig/BeardAnchor/Beard` pose the imported model's ten beard bones without creating a second beard mesh.
The beard remains anchored to the player independently of camera pitch and naturally enters the view when the player looks down.

Select `BodyRig/BeardAnchor/Beard/BeardAnimationPlayer` to edit the beard's `lift` and `lower` clips.
Select `BeardRoot`, `Joint02`, `Joint03`, or `Joint04` and manipulate those controls directly in the 3D viewport.

Select `Head/Camera3D/Viewmodel/FirstPersonWizardRig/BeardInteractionAnimationPlayer` to edit the left arm that reaches up with the beard.
The beard and arm clips share the same durations so they can be scrubbed side by side.

`BeardInventoryAnchor` contains three marker slots for future spell-card inventory presentation.
While looking down, holding `B` lifts the beard and left hand, and releasing `B` lowers them.
