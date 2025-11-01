# Build stage with testing
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine AS build
WORKDIR /src

# Copy project files
COPY ["SampleApp/BackEnd/BackEnd.csproj", "SampleApp/BackEnd/"]
COPY ["SampleApp/BackEnd.Tests/BackEnd.Tests.csproj", "SampleApp/BackEnd.Tests/"]

# Restore dependencies
RUN dotnet restore "SampleApp/BackEnd/BackEnd.csproj"

# Copy source
COPY . .

# Build
WORKDIR "/src/SampleApp/BackEnd"
RUN dotnet build "BackEnd.csproj" -c Release -o /app/build

# Publish
RUN dotnet publish "BackEnd.csproj" -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0-alpine AS runtime
WORKDIR /app

# Install curl for health checks
RUN apk add --no-cache curl tini

# Copy built application
COPY --from=build /app/publish .

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /sbin/nologin -D appuser && \
    chown -R appuser:appuser /app

USER appuser

# Health check endpoint
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Expose ports (8080: API, 9464: Prometheus metrics)
EXPOSE 8080 9464

# Use tini as init process to handle signals properly
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["dotnet", "BackEnd.dll"]
