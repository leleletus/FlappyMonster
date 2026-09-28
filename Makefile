# ──────────────────────────────────────────────────────────────────────────────
# FlappyMonster Makefile
# Basado en el Makefile de Friday Night Funkin' Rewritten por HTV04
#
# Targets disponibles:
#   make           → todo: lovefile + win64 + switch
#   make desktop   → lovefile + win64
#   make console   → lovefile + switch
#   make lovefile  → solo el .love (portátil, corre con cualquier LÖVE)
#   make win64     → ejecutable Windows 64-bit
#   make switch    → NRO (Homebrew Launcher)
#   make android   → APK debug (usa el submódulo love-android)
#   make android-reset → limpia los cambios del build dentro de love-android
#   make clean     → borra todo el directorio build/
#
# Estructura esperada de resources/:
#   resources/
#   ├── switch/
#   │   ├── love.elf   ← tu love.elf va acá
#   │   └── icon.jpg   ← 256×256 JPEG
#   └── win64/
#       └── love/      ← DLLs + love.exe de LÖVE 11.x para Windows
#
# Versión del juego: editá el archivo version.txt en la raíz.
# ──────────────────────────────────────────────────────────────────────────────

# ── Nombre del juego ──────────────────────────────────────────────────────────
GAME        := FlappyMonster
GAME_LOWER  := flappymonster
AUTHOR      := TuNombre

# ── Directorios ───────────────────────────────────────────────────────────────
SRC_DIR     := .
BUILD_DIR   := build
RELEASE_DIR := $(BUILD_DIR)/release

# ── Herramientas devkitPro ────────────────────────────────────────────────────
# En Windows (MSYS2/Git Bash) los paths son /c/devkitPro/...
# En Linux/macOS son $(DEVKITPRO)/tools/bin/...
# Ajustá según tu sistema:
DEVKITPRO   ?= /opt/devkitpro

NACPTOOL    := "$(DEVKITPRO)/tools/bin/nacptool"
ELF2NRO     := "$(DEVKITPRO)/tools/bin/elf2nro"

# ── Targets principales ───────────────────────────────────────────────────────
all: lovefile win64 switch android

desktop: lovefile win64

mobile: lovefile android

console: lovefile switch 

#lugar cd /d/mati/FlappyMonster


# ── lovefile ──────────────────────────────────────────────────────────────────
# Crea el .love (ZIP del código fuente).
# Excluye: build/, resources/, tools/, archivos de build y de sistema.
lovefile:
	@echo "━━━ [LOVEFILE] Empaquetando código fuente ━━━"
	@rm -rf $(BUILD_DIR)/lovefile
	@mkdir -p $(BUILD_DIR)/lovefile

	@zip -9 -r $(BUILD_DIR)/lovefile/$(GAME_LOWER).love $(SRC_DIR) \
		-x "build/*" \
		-x "server/published/*" \
		-x "resources/*" \
		-x "tools/*" \
		-x "*.love" \
		-x "*.nro" \
		-x "*.nsp" \
		-x "*.nacp" \
		-x "*.elf" \
		-x "*.AppImage" \
		-x "Makefile" \
		-x "*.sh" \
		-x "*.md" \
		-x ".git/*" \
		-x ".gitignore" \
		-x "keys.dat"

	@mkdir -p $(RELEASE_DIR)
	@rm -f $(RELEASE_DIR)/$(GAME_LOWER)-lovefile.zip
	@cd $(BUILD_DIR)/lovefile; zip -9 -r ../release/$(GAME_LOWER)-lovefile.zip .
	@echo "✓ $(RELEASE_DIR)/$(GAME_LOWER)-lovefile.zip"

# ── Windows 64-bit ────────────────────────────────────────────────────────────
# Requiere LÖVE 11.x para Windows en resources/win64/love/
# Descargá de https://love2d.org → Windows 64-bit → descomprimí en resources/win64/love/
win64: lovefile
	@echo "━━━ [WIN64] Compilando para Windows 64-bit ━━━"
	@rm -rf $(BUILD_DIR)/win64
	@mkdir -p $(BUILD_DIR)/win64

	@echo "1. Copiando DLLs de LÖVE..."
	@cp resources/win64/love/OpenAL32.dll    $(BUILD_DIR)/win64/
	@cp resources/win64/love/SDL2.dll        $(BUILD_DIR)/win64/
	@cp resources/win64/love/lua51.dll       $(BUILD_DIR)/win64/
	@cp resources/win64/love/mpg123.dll      $(BUILD_DIR)/win64/
	@cp resources/win64/love/love.dll        $(BUILD_DIR)/win64/
	@cp resources/win64/love/license.txt     $(BUILD_DIR)/win64/
	@cp resources/win64/love/msvcp120.dll    $(BUILD_DIR)/win64/ 2>/dev/null || true
	@cp resources/win64/love/msvcr120.dll    $(BUILD_DIR)/win64/ 2>/dev/null || true

	@echo "2. Fusionando love.exe + .love → .exe..."
	@cat resources/win64/love/love.exe $(BUILD_DIR)/lovefile/$(GAME_LOWER).love \
		> $(BUILD_DIR)/win64/$(GAME).exe

	@mkdir -p $(RELEASE_DIR)
	@rm -f $(RELEASE_DIR)/$(GAME_LOWER)-win64.zip
	@cd $(BUILD_DIR)/win64; zip -9 -r ../release/$(GAME_LOWER)-win64.zip .
	@echo "✓ $(RELEASE_DIR)/$(GAME_LOWER)-win64.zip"

# ── Nintendo Switch ───────────────────────────────────────────────────────────
# Poné en resources/switch/:
#   love.elf  → runtime LovePotion / LÖVE para Switch
#   icon.jpg  → ícono 256×256 JPEG
switch: lovefile
	@echo "━━━ [SWITCH] Compilando NRO para Nintendo Switch ━━━"
	@rm -rf $(BUILD_DIR)/switch
	@mkdir -p $(BUILD_DIR)/switch/romfs
	@mkdir -p $(BUILD_DIR)/switch/nro

	@echo "1. Copiando .love al RomFS..."
	@cp $(BUILD_DIR)/lovefile/$(GAME_LOWER).love \
		$(BUILD_DIR)/switch/romfs/game.love

	@echo "2. Generando NACP (metadata)..."
	@$(NACPTOOL) --create "$(GAME)" "$(AUTHOR)" \
		"$$(cat version.txt 2>/dev/null || echo '1.0.0')" \
		$(BUILD_DIR)/switch/$(GAME_LOWER).nacp

	@echo "3. Generando NRO..."
	@$(ELF2NRO) resources/switch/love.elf \
		$(BUILD_DIR)/switch/nro/$(GAME).nro \
		--icon=resources/switch/icon.jpg \
		--nacp=$(BUILD_DIR)/switch/$(GAME_LOWER).nacp \
		--romfsdir=$(BUILD_DIR)/switch/romfs

	@echo "4. Empaquetando ZIP..."
	@mkdir -p $(RELEASE_DIR)
	@cd $(BUILD_DIR)/switch/nro && \
		zip -9 -r ../../release/$(GAME_LOWER)-switch.zip .
	@echo "✓ $(RELEASE_DIR)/$(GAME_LOWER)-switch.zip"

	@echo "━━━ LISTO (Switch) ━━━"
	@echo "    Copiá el NRO a la SD: /switch/$(GAME_LOWER)/$(GAME).nro"

# ── Android ───────────────────────────────────────────────────────────────────
# Requiere Android SDK + NDK y un JDK. Definí ANDROID_HOME con la ruta del SDK
# (por defecto ~/Android/Sdk).
#
# resources/android/love-android es un submódulo git (love2d/love-android 11.5a).
# No se modifica a mano: todo lo propio del juego vive en resources/android/overlay/
# (misma estructura de carpetas) y se copia encima antes de compilar.
# `make android-reset` deja el submódulo limpio otra vez.
LOVE_ANDROID := resources/android/love-android
ANDROID_HOME ?= $(HOME)/Android/Sdk

android: lovefile
	@echo "━━━ [ANDROID] Compilando APK para Android ━━━"
	@if [ ! -f "$(LOVE_ANDROID)/gradlew" ] || [ ! -f "$(LOVE_ANDROID)/love/src/jni/love/Android.mk" ]; then \
		echo "Descargando submódulo love-android (y LÖVE)..."; \
		git submodule update --init --recursive $(LOVE_ANDROID); \
	fi
	@if [ ! -f "$(LOVE_ANDROID)/local.properties" ]; then \
		echo "sdk.dir=$(ANDROID_HOME)" > $(LOVE_ANDROID)/local.properties; \
	fi

	@echo "1. Copiando .love a los assets de Android..."
	@mkdir -p $(LOVE_ANDROID)/app/src/embed/assets
	@cp $(BUILD_DIR)/lovefile/$(GAME_LOWER).love $(LOVE_ANDROID)/app/src/embed/assets/game.love

	@echo "1.5. Aplicando overlay (nombre, icono, Application ID, Gradle 8.7)..."
	@cp -r resources/android/overlay/. $(LOVE_ANDROID)/
	@mkdir -p $(LOVE_ANDROID)/app/src/embed/res/drawable
	@cp resources/android/icon.jpg $(LOVE_ANDROID)/app/src/embed/res/drawable/app_icon.jpg

	@echo "2. Compilando con Gradle (esto puede tardar)..."
	@cd $(LOVE_ANDROID) && ./gradlew assembleEmbedNoRecordDebug -Dorg.gradle.jvmargs="-Xmx8g"

	@echo "3. Copiando APK generado a release/..."
	@mkdir -p $(RELEASE_DIR)
	@find $(LOVE_ANDROID)/app/build/outputs/apk/ -name "*debug.apk" -exec cp {} $(RELEASE_DIR)/$(GAME_LOWER)-android-debug.apk \;
	@echo "✓ $(RELEASE_DIR)/$(GAME_LOWER)-android-debug.apk"

# Descarta lo que el build copió dentro del submódulo (conserva local.properties).
android-reset:
	@git -C $(LOVE_ANDROID) checkout -- .
	@git -C $(LOVE_ANDROID) clean -fdq -e local.properties
	@echo "✓ love-android limpio"

# ── Limpieza ──────────────────────────────────────────────────────────────────
clean:
	@echo "Limpiando build/..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Listo"

.PHONY: all desktop console mobile lovefile win64 switch android android-reset clean
