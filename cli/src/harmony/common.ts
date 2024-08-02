import {
  readJSON,
  pathExists,
  writeJSON,
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
      // If the plugin has no platform tag for the android, it's incompatible
      !getPluginPlatform(plugin, 'android')
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
  let appJson5Content = await readJSON(appJson5Path, { encoding: 'utf-8' });
  appJson5Content.app.bundleName = appId;
  await writeJSON(appJson5Path, appJson5Content, { encoding: 'utf-8', spaces: '\t' });

  const appStringPath = resolve(config.harmony.appDirAbs, 'resources/base/element/string.json');
  let appStringContent = await readJSON(appStringPath, { encoding: 'utf-8' });
  for (let i = 0; i < appStringContent.string.length; i++) {
    const stringItem = appStringContent.string[i];
    if (stringItem.name === 'app_name') {
      stringItem.value = appName;
      break;
    }
  }
  await writeJSON(appStringPath, appStringContent, { encoding: 'utf-8', spaces: '\t' });

  const stringsParts = ['base', 'en_US', 'zh_CN']
  for (let i = 0; i < stringsParts.length; i++) {
    const stringsPart = stringsParts[i];
    
    const stringsPath = resolve(config.harmony.assetsDirAbs, stringsPart, 'element/string.json');
    if (await pathExists(stringsPath)) {
      let stringsJson = await readJSON(stringsPath, { encoding: 'utf-8' });
      for (let i = 0; i < stringsJson.string.length; i++) {
        const stringItem = stringsJson.string[i];
        if (stringItem.name === 'EntryAbility_label') {
          stringItem.value = appName;
          break;
        }
      }
      await writeJSON(stringsPath, stringsJson, { encoding: 'utf-8', spaces: '\t' });
    }
  }
}
