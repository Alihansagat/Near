# NEAR heart mascots

Approved source concept: `output/imagegen/near-heart-mascots-moods-v1.png` at the project root.
`hearts-moods.png` is a derived atlas generated with built-in image_gen.
Top row: male; bottom row: female. Columns: joyful, loving, missing, anxious, sleepy, angry.
`lib/mascot.dart` contains measured bounds for each sprite; the original image is rendered directly without destructive extraction. Keep its 1536×1024 coordinate system when replacing it.

Generation prompt: Reorganize the approved NEAR mascot artwork into a 6-column, 2-row atlas with twelve isolated full-body sprites. Preserve berry male heart with scarf and tuft, pink female heart with flower, outline, palette and facial style. Each column shows the same mood in both rows: joyful, loving, missing-you, anxious, sleepy, angry. Loving characters hug themselves. Keep full limbs, generous spacing, uniform warm off-white background, no grid, no labels, no scene. Do not redesign the approved characters.
