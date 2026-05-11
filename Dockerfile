FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY src/TmuxAlerts/TmuxAlerts.csproj TmuxAlerts/
RUN dotnet restore TmuxAlerts/TmuxAlerts.csproj
COPY src/TmuxAlerts/ TmuxAlerts/
RUN dotnet publish TmuxAlerts/TmuxAlerts.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
EXPOSE 7777
ENTRYPOINT ["dotnet", "TmuxAlerts.dll"]
