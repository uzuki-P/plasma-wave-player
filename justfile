plugin := "uzuki.waveplayer"
icon := "uzuki-waveplayer"
icon_dir := env("HOME") / ".local/share/icons/hicolor/scalable/apps"

default:
    @just --list

# Run the widget in its own window
dev:
    plasmawindowed "{{justfile_directory()}}/package"

# Save compact and popup snapshots; pass --display to render layer effects
snapshot *args:
    python3 -I dev/snapshot.py {{args}}

# Install the widget, or upgrade it when already installed
install:
    kpackagetool6 -t Plasma/Applet -s {{plugin}} >/dev/null 2>&1 \
        && kpackagetool6 -t Plasma/Applet -u package \
        || kpackagetool6 -t Plasma/Applet -i package
    install -Dm644 package/contents/icons/{{icon}}.svg "{{icon_dir}}/{{icon}}.svg"

# Install, then restart plasmashell so the panel drops its cached QML
reload: install
    systemctl --user restart plasma-plasmashell

# Uninstall the widget package
uninstall:
    kpackagetool6 -t Plasma/Applet -r {{plugin}}
    rm -f "{{icon_dir}}/{{icon}}.svg"
