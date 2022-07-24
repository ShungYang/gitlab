#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

RUN apt-get update \
    &&  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata

RUN TZ=Asia/Taipei \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build

ARG SONAR_PROJECT_KEY=shawn.yang_hello-sonarqube_AYEpkWv83uQ5L0gZgso2
ARG SONAR_HOST_URL=https://sonarqube.mic.com.tw
ARG SONAR_TOKEN
ARG CI_COMMIT_SHORT_SHA

WORKDIR /src
COPY ["WebApi.Service.Discovery/WebApi.Service.Discovery.csproj", "WebApi.Service.Discovery/"]
COPY ["WebApi.Service.Discovery/nuget.config", "WebApi.Service.Discovery/"]
RUN dotnet restore "WebApi.Service.Discovery/WebApi.Service.Discovery.csproj"
COPY . .
WORKDIR "/src/WebApi.Service.Discovery"
RUN apt-get update && apt-get install --yes openjdk-11-jre
RUN dotnet tool install --global dotnet-sonarscanner
ENV PATH="$PATH:/root/.dotnet/tools"
RUN dotnet sonarscanner begin \
    /k:"$SONAR_PROJECT_KEY" \
    /v:"$CI_COMMIT_SHORT_SHA" \
    /d:sonar.login="$SONAR_TOKEN" \
    /d:sonar.host.url="$SONAR_HOST_URL" \
    /d:sonar.qualitygate.wait="true"
RUN dotnet build "WebApi.Service.Discovery.csproj" -c Release -o /app/build
RUN dotnet sonarscanner end /d:sonar.login="$SONAR_TOKEN"

FROM build AS publish
RUN dotnet publish "WebApi.Service.Discovery.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_ENVIRONMENT dev
ENV ASPNETCORE_PATHBASE /Discovery
ENV ASPNETCORE_VERSION 1.1.0
ENTRYPOINT ["dotnet", "WebApi.Service.Discovery.dll"]

