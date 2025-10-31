# Dockerfile for .NET 9.0 Frontend (Blazor)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 8081

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY SampleApp/FrontEnd/FrontEnd.csproj ./
RUN dotnet restore "FrontEnd.csproj"
COPY SampleApp/FrontEnd/. ./
RUN dotnet publish "FrontEnd.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "FrontEnd.dll"]
