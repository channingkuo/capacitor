import {
  readFile,
  pathExists,
  writeFile,
} from '@ionic/utils-fs';
import { join, resolve } from 'path';

import { checkCapacitorPlatform } from '../common';
import { getIncompatibleCordovaPlugins } from '../cordova';
import type { Config } from '../definitions';
import { PluginType, getPluginPlatform } from '../plugin';
import type { Plugin } from '../plugin';
import { convertToUnixPath } from '../util/fs';

export async function checkHarmonyPackage(
  config: Config,
): Promise<string | null> {
  return checkCapacitorPlatform(config, 'harmony');
}

export async function getHarmonyPlugins(
  allPlugins: Plugin[],
): Promise<Plugin[]> {
  const resolved = await Promise.all(
    allPlugins.map(async plugin => await resolvePlugin(plugin)),
  );
  return resolved.filter((plugin): plugin is Plugin => !!plugin);
}

export async function resolvePlugin(plugin: Plugin): Promise<Plugin | null> {
  const platform = 'harmony';
  if (plugin.manifest?.harmony) {
    let pluginFilesPath = plugin.manifest.harmony.src
      ? plugin.manifest.harmony.src
      : platform;
    const absolutePath = join(plugin.rootPath, pluginFilesPath, plugin.id);
    // Harmony folder shouldn't have subfolders, but they used to, so search for them for compatibility reasons
    if (await pathExists(absolutePath)) {
      pluginFilesPath = join(platform, plugin.id);
    }
    plugin.harmony = {
      type: PluginType.Core,
      path: convertToUnixPath(pluginFilesPath),
    };
  } else if (plugin.xml) {
    plugin.harmony = {
      type: PluginType.Cordova,
      path: 'src/' + platform,
    };
    if (
      getIncompatibleCordovaPlugins(platform).includes(plugin.id) ||
      !getPluginPlatform(plugin, platform)
    ) {
      plugin.harmony.type = PluginType.Incompatible;
    }
  } else {
    return null;
  }
  return plugin;
}

/**
 * Update an Harmony project with the desired app name and appId.
 */
export async function editProjectSettingsHarmony(
  config: Config,
): Promise<void> {
  const appId = config.app.appId;
  const appName = config.app.appName
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '\\"')
    .replace(/'/g, "\\'");

  const appJson5Path = resolve(config.harmony.appDirAbs, 'app.json5');
  let appJson5ContentString = await readFile(appJson5Path, { encoding: 'utf-8' });
  let appJson5Content = JSON.parse(appJson5ContentString);
  appJson5Content.app.bundleName = appId;
  appJson5ContentString = JSON.stringify(appJson5Content, null, 2);
  await writeFile(appJson5Path, appJson5ContentString, { encoding: 'utf-8' });

  const appStringPath = resolve(config.harmony.appDirAbs, 'resources/base/element/string.json');
  let appString = await readFile(appStringPath, { encoding: 'utf-8' });
  let appStringContent = JSON.parse(appString);
  for (let i = 0; i < appStringContent.string.length; i++) {
    const stringItem = appStringContent.string[i];
    if (stringItem.name === 'app_name') {
      stringItem.value = appName;
      break;
    }
  }
  appString = JSON.stringify(appStringContent, null, 2);
  await writeFile(appStringPath, appString, { encoding: 'utf-8' });

  const stringsParts = ['base', 'en_US', 'zh_CN']
  for (let i = 0; i < stringsParts.length; i++) {
    const stringsPart = stringsParts[i];
    
    const stringsPath = resolve(config.harmony.assetsDirAbs, stringsPart, 'element/string.json');
    if (await pathExists(stringsPath)) {
      let stringsValue = await readFile(stringsPath, { encoding: 'utf-8' });
      let stringsJson = JSON.parse(stringsValue);
      for (let i = 0; i < stringsJson.string.length; i++) {
        const stringItem = stringsJson.string[i];
        if (stringItem.name === 'CareAbility_label') {
          stringItem.value = appName;
          break;
        }
      }
      stringsValue = JSON.stringify(stringsJson, null, 2);
      await writeFile(stringsPath, stringsValue, { encoding: 'utf-8' });
    }
  }
}
