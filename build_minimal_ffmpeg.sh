#!/bin/bash

# エラーが起きたらスクリプトを即終了する
set -e

# ==========================================
# 引数処理
# 第1引数でFFmpegのタグを指定可能。未指定の場合は "n9.0.1" を使用。
# 例: ./build_minimal_ffmpeg.sh n9.0.1
# ==========================================
FFMPEG_TAG="${1:-n9.0.1}"

# スクリプト自体が配置されている絶対パスを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 作業ディレクトリと出力先をスクリプト配置場所のサブディレクトリに変更
BUILD_DIR="$SCRIPT_DIR/ffmpeg_build"
TARGET_DIR="$SCRIPT_DIR/ffmpeg_bin"

mkdir -p "$BUILD_DIR" "$TARGET_DIR"
cd "$BUILD_DIR"

# 1. 必要なビルドツールのインストール（MinGW・ビルドツール）
sudo apt update
sudo apt install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    cmake \
    git \
    nasm \
    ninja-build \
    pkg-config \
    mingw-w64 \
    mingw-w64-tools

# Cross compile prefix
CROSS_PREFIX="x86_64-w64-mingw32-"
HOST="x86_64-w64-mingw32"

# MinGWを posix スレッドモデルに変更 (x265のC++11 std::thread要件対応)
sudo update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix || true
sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix || true

export PKG_CONFIG_PATH="$BUILD_DIR/lib/pkgconfig"

# --------------------------------------------------
# 2. Build libfdk-aac
# --------------------------------------------------
echo "==> libfdk-aac の取得 / 更新を行います..."
if [ ! -d "mstorsjo-fdk-aac" ]; then
    git clone --depth 1 https://github.com/mstorsjo/fdk-aac mstorsjo-fdk-aac
    cd mstorsjo-fdk-aac
else
    cd mstorsjo-fdk-aac
    git fetch --depth 1 origin
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
    make distclean || make clean || true
fi

./autogen.sh
./configure \
    --host=$HOST \
    --prefix="$BUILD_DIR" \
    --enable-static \
    --disable-shared
make -j$(nproc)
make install
cd "$BUILD_DIR"

# --------------------------------------------------
# 3. Build x265 (libx265) 
# --------------------------------------------------
echo "==> x265 の取得 / 更新を行います..."
if [ ! -d "x265_git" ]; then
    git clone https://github.com/Multicorewareinc/x265.git x265_git
    cd x265_git
else
    cd x265_git
    git fetch origin
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
    rm -rf "$BUILD_DIR/x265_git/build/crosscompile"
fi

# ディレクトリを作成してから移動
cd "$BUILD_DIR"
mkdir -p x265_git/build/crosscompile
cd x265_git/build/crosscompile

# MinGW用のToolchain設定ファイルを準備
cat << 'EOF' > cross_mingw.cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

cmake -G "Ninja" ../../source \
    -DCMAKE_TOOLCHAIN_FILE=cross_mingw.cmake \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR" \
    -DENABLE_SHARED=OFF \
    -DENABLE_CLI=OFF
ninja
ninja install

# x265 の pkg-config ファイルに静的 C++ ライブラリ依存を自動追加
if [ -f "$BUILD_DIR/lib/pkgconfig/x265.pc" ]; then
    sed -i.bak 's/Libs.private:.*/Libs.private: -lstdc++ -lwinpthread/g' "$BUILD_DIR/lib/pkgconfig/x265.pc"
fi

cd "$BUILD_DIR"

# --------------------------------------------------
# 4. Build Minimal FFmpeg (引数によるTag指定)
# --------------------------------------------------
echo "==> FFmpeg のタグ: $FFMPEG_TAG の取得 / チェックアウトを行います..."
if [ ! -d "ffmpeg" ]; then
    git clone --depth 1 --branch "$FFMPEG_TAG" https://git.ffmpeg.org/ffmpeg.git ffmpeg
    cd ffmpeg
else
    cd ffmpeg
    # 指定されたタグがローカルに存在するか確認
    if git rev-parse -q --verify "refs/tags/$FFMPEG_TAG" >/dev/null; then
        # 前回と同じタグ（またはローカルに既に存在するタグ）の場合
        echo "タグ $FFMPEG_TAG は既に存在します。リポジトリを最新化します..."
        git fetch --depth 1 origin tag "$FFMPEG_TAG"
        git checkout "$FFMPEG_TAG"
        git reset --hard "$FFMPEG_TAG"
    else
        # 新しいタグが指定された場合
        echo "新しいタグ $FFMPEG_TAG を取得します..."
        git fetch --depth 1 origin tag "$FFMPEG_TAG"
        git checkout "$FFMPEG_TAG"
    fi
fi

make distclean || make clean || true

./configure \
    --prefix="$TARGET_DIR" \
    --arch=x86_64 \
    --target-os=mingw32 \
    --cross-prefix=$CROSS_PREFIX \
    --pkg-config=pkg-config \
    --extra-cflags="-I$BUILD_DIR/include" \
    --extra-cxxflags="-I$BUILD_DIR/include" \
    --extra-ldflags="-L$BUILD_DIR/lib -static -static-libgcc -static-libstdc++" \
    --pkg-config-flags="--static" \
    --enable-static \
    --disable-shared \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libx265 \
    --disable-everything \
    --enable-ffmpeg \
    --enable-decoder=h264,aac,pcm_bluray,subrip,ass \
    --enable-encoder=libx265,libfdk_aac \
    --enable-demuxer=mov,matroska,mpegts,srt,ass \
    --enable-muxer=mov,mp4,ipod,matroska \
    --enable-parser=h264,hevc,aac \
    --enable-protocol=file,cenc \
    --enable-filter=aresample

make -j$(nproc)
make install

echo "=========================================="
echo "ビルドが完了しました。"
echo "FFmpeg Tag: $FFMPEG_TAG"
echo "出力ファイル: $TARGET_DIR/bin/ffmpeg.exe"
echo "=========================================="
