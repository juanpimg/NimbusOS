# NimbusShell F10-T03 — perfil de terminal Nimbus.
# Grupos y claves exactos de src/profile/Profile.cpp upstream
# (invent.kde.org/utilities/konsole): [General] Name + Parent (el writer
# guarda ahi "Parent"; FALLBACK/ = perfil integrado), [Appearance] Font,
# ColorScheme, AntiAliasFonts, BoldIntense. La opacidad y el blur NO son del
# perfil: viven en el esquema de color (src/colorscheme/ColorScheme.cpp lee
# Opacity/Blur de [General] del .colorscheme) -> ver Nimbus.colorscheme.

[General]
Name=Nimbus
Parent=FALLBACK/

[Appearance]
AntiAliasFonts=true
BoldIntense=true
ColorScheme=Nimbus
Font=JetBrains Mono,12,-1,5,400,0,0,0,0,0

[Scrolling]
HistorySize=10000
