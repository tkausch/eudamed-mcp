# Packaging follows https://www.swift.org/documentation/server/guides/packaging.html:
# build a release binary, then copy only that binary into a slim runtime image.

# ---- Build ----
FROM swift:latest AS build
WORKDIR /build

# Resolve dependencies first so they are cached across source changes.
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Tests/ is needed too: SwiftPM refuses to load a package with a missing target directory.
# It stays in this build stage; the run image below copies only the binary.
COPY Sources ./Sources
COPY Tests ./Tests
RUN swift build -c release --product eudamed-mcp \
    && cp "$(swift build -c release --show-bin-path)/eudamed-mcp" /build/eudamed-mcp

# ---- Run ----
# swift:slim ships the Swift runtime libraries (including FoundationNetworking's
# libcurl, used by EudamedClient via URLSession), tzdata and CA certificates, so
# the binary links them dynamically instead of using --static-swift-stdlib.
# Keep it on the same Swift release as the build image.
FROM swift:slim
RUN useradd --system --create-home --home-dir /app app
WORKDIR /app
COPY --from=build /build/eudamed-mcp /app/eudamed-mcp
USER app

# Runtime configuration. Set these on the container (`docker run -e`, or the
# hosting platform's variables); never bake a real token into the image.
# - EUDAMED_MCP_TOKEN: bearer token required on /mcp. Empty = open endpoint.
# - EUDAMED_MCP_ALLOWED_HOSTS: comma-separated Host headers to accept. Empty = not checked.
# - PORT: port to listen on. Platforms such as Railway set it automatically.
ENV HOST=0.0.0.0 \
    PORT=8080 \
    EUDAMED_MCP_TOKEN="" \
    EUDAMED_MCP_ALLOWED_HOSTS=""

EXPOSE 8080
ENTRYPOINT ["/app/eudamed-mcp"]
CMD ["serve", "--env", "production"]
