#!/usr/bin/env node
'use strict';

// Keep the required PlanetsLib version in sync with the newest version published
// to the mod portal. Runs before semantic-release, which commits info.json as
// part of the release commit.

const fs = require('node:fs');
const path = require('node:path');

const DEPENDENCY_NAME = 'PlanetsLib';
const MOD_PORTAL_URL = `https://mods.factorio.com/api/mods/${DEPENDENCY_NAME}`;
const INFO_PATH = path.resolve(__dirname, '..', '..', 'info.json');

function parseVersion(version) {
  return String(version)
    .split('.')
    .map((part) => {
      const match = /^\d+/.exec(part);
      return match ? Number(match[0]) : 0;
    });
}

function compareVersions(left, right) {
  const leftParts = parseVersion(left);
  const rightParts = parseVersion(right);
  const length = Math.max(leftParts.length, rightParts.length);

  for (let index = 0; index < length; index += 1) {
    const difference = (leftParts[index] || 0) - (rightParts[index] || 0);
    if (difference !== 0) {
      return difference;
    }
  }

  return 0;
}

function parseDependency(dependency) {
  const match = /^([A-Za-z0-9_.-]+)(?:\s*(>=|>|=)\s*([0-9][0-9A-Za-z.+-]*))?$/.exec(dependency);

  if (!match) {
    return null;
  }

  return {
    name: match[1],
    operator: match[2],
    version: match[3],
  };
}

async function getLatestAvailableVersion() {
  const response = await fetch(MOD_PORTAL_URL, {
    headers: { 'User-Agent': 'factorio-mod-release-script' },
    signal: AbortSignal.timeout(30000),
  });

  if (!response.ok) {
    throw new Error(`Failed to query the mod portal (${response.status} ${response.statusText})`);
  }

  const data = await response.json();
  const releases = Array.isArray(data.releases) ? data.releases : [];
  const versions = releases
    .filter((release) => release && release.version && !release.deprecated)
    .map((release) => release.version);

  if (versions.length === 0) {
    throw new Error(`The mod portal returned no releases for ${DEPENDENCY_NAME}`);
  }

  return versions.reduce((latest, version) => (
    compareVersions(version, latest) > 0 ? version : latest
  ));
}

async function main() {
  const infoText = fs.readFileSync(INFO_PATH, 'utf8');
  const info = JSON.parse(infoText);
  const dependencies = Array.isArray(info.dependencies) ? info.dependencies : [];

  const dependency = dependencies
    .filter((entry) => typeof entry === 'string')
    .map((entry) => ({ text: entry, parsed: parseDependency(entry) }))
    .find(({ parsed }) => parsed && parsed.name === DEPENDENCY_NAME);

  if (!dependency) {
    throw new Error(`Could not find a "${DEPENDENCY_NAME}" dependency in ${INFO_PATH}`);
  }

  const latestVersion = await getLatestAvailableVersion();
  const requiredVersion = dependency.parsed.version || '0.0.0';

  if (compareVersions(requiredVersion, latestVersion) >= 0) {
    console.log(
      `${DEPENDENCY_NAME} ${requiredVersion} is already at or above the latest mod portal version ${latestVersion}.`,
    );
    return;
  }

  const updatedDependency = dependency.parsed.version
    ? dependency.text.replace(dependency.parsed.version, latestVersion)
    : `${DEPENDENCY_NAME} >= ${latestVersion}`;

  const serializedDependency = JSON.stringify(dependency.text);
  if (!infoText.includes(serializedDependency)) {
    throw new Error(`Could not locate "${dependency.text}" in ${INFO_PATH}`);
  }

  const updatedInfoText = infoText.replace(serializedDependency, JSON.stringify(updatedDependency));
  JSON.parse(updatedInfoText);

  fs.writeFileSync(INFO_PATH, updatedInfoText);
  console.log(
    `Bumped ${DEPENDENCY_NAME} dependency from "${dependency.text}" to "${updatedDependency}".`,
  );
}

main().catch((error) => {
  console.error(`Failed to update the ${DEPENDENCY_NAME} dependency: ${error.message}`);
  process.exit(1);
});
