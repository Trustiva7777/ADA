# Dockerfile for .NET 9.0 Backend
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY SampleApp/BackEnd/BackEnd.csproj ./
RUN dotnet restore "BackEnd.csproj"
COPY SampleApp/BackEnd/. ./
RUN dotnet publish "BackEnd.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "BackEnd.dll"]
