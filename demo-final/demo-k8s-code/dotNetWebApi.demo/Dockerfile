#See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src
COPY ["dotNetWebApi.demo/dotNetWebApi.demo.csproj", "dotNetWebApi.demo/"]
RUN dotnet restore "dotNetWebApi.demo/dotNetWebApi.demo.csproj"
COPY . .
WORKDIR "/src/dotNetWebApi.demo"
RUN dotnet build "dotNetWebApi.demo.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "dotNetWebApi.demo.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "dotNetWebApi.demo.dll"]