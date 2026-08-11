-- Managed by Lacuna Shell. Persistent frame chrome must not inherit theme
-- layer-shell transforms; sidebar and flyout motion is rendered inside QML.
hl.layer_rule({
  match = { namespace = "^(lacuna-bar-frame|lacuna[.]menu-menu-.*)$" },
  no_anim = true,
  animation = "none",
})
