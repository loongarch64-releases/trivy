#!/bin/bash
set -euo pipefail

UPSTREAM_OWNER=aquasecurity
UPSTREAM_REPO=trivy
VERSION="${1:-}"

# 获取 ABI 参数
FILE_SERVER="http://10.180.200.67:8000"
ABI="${2:-}"
if [ -z "${VERSION}" ] || [ -z "${ABI}" ]; then
    echo "❌ Error: Upload file need VERSION and ABI."
    echo "Usage: abi1.0 use loongarch64abi1, abi2.0 use loongarch64"
    echo "Example: ./release.sh 9.5.2 loongarch64abi1"
    exit 1
fi
UPLOAD_PATH="releases/${2}/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/${VERSION}"

echo "   🏢 Org:   ${UPSTREAM_OWNER}"
echo "   📦 Proj:  ${UPSTREAM_REPO}"
echo "   🏷️  Ver:   ${VERSION}"
echo "   🏷️  ABI:   ${ABI}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DISTS="${ROOT_DIR}/dists"

if [ ! -d "${DISTS}/${VERSION}" ]; then
    echo "❌ Error: Distribution directory for version ${VERSION} does not exist."
    echo "Please run build.sh ${VERSION} first."
    exit 1
fi

# 检查 gh 命令是否安装
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed."
    echo "Please install it from https://cli.github.com/"
    exit 1
fi

# 检查是否已登录 gh
if ! gh auth status &> /dev/null; then
    echo "❌ Error: Not authenticated with GitHub CLI."
    echo "Please run 'gh auth login' first."
    exit 1
fi

# 检查版本标签是否已存在
if gh release view "${VERSION}" &> /dev/null; then
    echo "❌ Error: Release ${VERSION} already exists."
    exit 1
fi

echo "🚀 Creating GitHub release for ${UPSTREAM_OWNER}/${UPSTREAM_REPO} ${VERSION}..."

# 准备发布说明
RELEASE_NOTES="${DISTS}/${VERSION}/release-notes.md"
if [ -f "${RELEASE_NOTES}" ]; then
    echo "📝 Using existing release notes from ${RELEASE_NOTES}"
else
    echo "📝 Creating default release notes..."
    cat > "${RELEASE_NOTES}" <<EOF
## Changes
- Release ${ABI} version ${VERSION}

## Build Information
- Build Time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Project: ${UPSTREAM_REPO}
- Organization: ${UPSTREAM_OWNER}
EOF
fi

# 查找要上传的资产文件
ASSETS=()
if [ -d "${DISTS}/${VERSION}" ]; then
    echo "📦 Looking for assets in ${DISTS}/${VERSION}..."
    while IFS= read -r -d '' file; do
        if [ "$(basename "$file")" != "release-notes.md" ] && [ "$(basename "$file")" != "release.txt" ]; then
            ASSETS+=("$file")
            echo "   📄 Found asset: $(basename "$file")"
        fi
    done < <(find "${DISTS}/${VERSION}" -type f -print0)
fi

##### 上传到文件服务器
if [ ${#ASSETS[@]} -gt 0 ]; then
    echo ""
    echo "📤 Uploading assets to ${FILE_SERVER}/${UPLOAD_PATH}/ ..."
    for file in "${ASSETS[@]}"; do
        filename="$(basename "$file")"
        echo "   ⬆️  Uploading: ${filename}"
        if ! curl -s -F "file=@${file}" "${FILE_SERVER}/${UPLOAD_PATH}/"; then
            echo "   ❌ Error: Failed to upload ${filename}, aborting."
            exit 1
        fi
        echo "   ✅ Uploaded: ${filename}"
    done
    echo "✅ All assets uploaded successfully to ${FILE_SERVER}!"
fi

##### 上传到github
# 创建发布命令
RELEASE_CMD=(gh release create "${VERSION}" --title "Release ${VERSION}" --notes-file "${RELEASE_NOTES}")

# 添加资产文件
if [ ${#ASSETS[@]} -gt 0 ]; then
    RELEASE_CMD+=("${ASSETS[@]}")
fi

echo "🔧 Executing release command..."
echo "   Command: ${RELEASE_CMD[*]}"

# 执行发布
"${RELEASE_CMD[@]}"

echo "✅ GitHub release created successfully!"
echo "🔗 Release URL: https://github.com/${UPSTREAM_OWNER}/${UPSTREAM_REPO}/releases/tag/${VERSION}"
