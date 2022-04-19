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
WORKDIR /src
COPY ["WebApi.Service.Discovery/WebApi.Service.Discovery.csproj", "WebApi.Service.Discovery/"]
COPY ["WebApi.Service.Discovery/nuget.config", "WebApi.Service.Discovery/"]
RUN dotnet restore "WebApi.Service.Discovery/WebApi.Service.Discovery.csproj"
COPY . .
WORKDIR "/src/WebApi.Service.Discovery"
RUN dotnet build "WebApi.Service.Discovery.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "WebApi.Service.Discovery.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENV ASPNETCORE_ENVIRONMENT dev
ENV ASPNETCORE_PATHBASE /Service-Discovery
ENV ASPNETCORE_VERSION 1.1.0
ENTRYPOINT ["dotnet", "WebApi.Service.Discovery.dll"]
