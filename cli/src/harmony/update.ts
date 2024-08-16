import {
  copy,
  pathExists,
  readFile,
  readJSON,
  writeFile,
  writeJSON,
  mkdirSync,
} from '@ionic/utils-fs';
import JSON5 from 'json5';
import Debug from 'debug';
import { basename, resolve } from 'path';

import { checkPlatformVersions, runTask } from '../common';
import type { Config } from '../definitions';
import {
  PluginType,
  getPluginType,
  getPlugins,
  printPlugins,
} from '../plugin';
import type { Plugin } from '../plugin';
import { copy as copyTask } from '../tasks/copy';

import { getHarmonyPlugins } from './common';

const platform = 'harmony';
const debug = Debug('capacitor:harmony:update');

export async function updateHarmony(config: Config): Promise<void> {
  const plugins = await getPluginsTask(config);

  const capacitorPlugins = plugins.filter(
    p => getPluginType(p, platform) === PluginType.Core,
  );

  printPlugins(capacitorPlugins, 'harmony');

  const srcPath = resolve(config.app.rootDir, 'node_modules', '@capacitor', config.harmony.name, 'capacitor');
  const targetPath = resolve(config.app.rootDir, config.harmony.name, 'capacitor');
  mkdirSync(targetPath, { recursive: true })
  copy(srcPath, targetPath);

  await writePluginsJson(config, capacitorPlugins);
  if (!(await pathExists(config.harmony.webDirAbs))) {
    await copyTask(config, platform);
  }
  const incompatibleCordovaPlugins = plugins.filter(
    p => getPluginType(p, platform) === PluginType.Incompatible,
  );
  printPlugins(incompatibleCordovaPlugins, platform, 'incompatible');
  await checkPlatformVersions(config, platform);
}

interface PluginsJsonEntry {
  plugin: string;
  pluginClass: string;
  module: string;
  moduleAlias: string;
}

async function writePluginsJson(
  config: Config,
  plugins: Plugin[],
): Promise<void> {
  const pluginJsonEntry = await findHarmonyPluginJsonEntry(plugins);
  const pluginsJsonPath = resolve(
    config.harmony.configDirAbs,
    'capacitor.plugins.json',
  );

  await writeJSON(pluginsJsonPath, pluginJsonEntry, { spaces: '\t' });

  const srcPath = resolve(config.app.rootDir, config.harmony.name, 'entry');
  const projectBuildProfilePath = resolve(config.app.rootDir, config.harmony.name, 'build-profile.json5');
  const pluginDependencePath = resolve(srcPath, 'oh-package.json5');
  const buildProfilePath = resolve(srcPath, 'build-profile.json5');
  const pluginInfo = await readFile(pluginDependencePath, { encoding: 'utf-8' });
  let pluginInfoData = JSON5.parse(pluginInfo);
  const buildProfileInfo = await readFile(buildProfilePath, { encoding: 'utf-8' });
  let buildProfileInfoData = JSON5.parse(buildProfileInfo);
  const projectBuildProfileInfo = await readFile(projectBuildProfilePath, { encoding: 'utf-8' });
  let projectBuildProfileInfoData = JSON5.parse(projectBuildProfileInfo);

  for (const pluginEntry of pluginJsonEntry) {
    pluginInfoData.dependencies[pluginEntry.plugin] = `file:../${pluginEntry.plugin}`;
    buildProfileInfoData.buildOption.arkOptions.runtimeOnly.packages.push(pluginEntry.plugin);

    projectBuildProfileInfoData.modules.push({
      name: pluginEntry.module,
      // https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-har-import-0000001547293682-V5
      // 引用本地模块源码（该本地模块必须与宿主模块归属于同一个工程）
      srcPath: `./${pluginEntry.plugin}`
    });
  }
  projectBuildProfileInfoData.modules.push({
    name: "Capacitor",
    srcPath: "./capacitor",
  });
  for (const plugin of plugins) {
    if (!plugin.harmony || getPluginType(plugin, platform) !== PluginType.Core) {
      continue;
    }
    const srcPath = resolve(plugin.rootPath, plugin.harmony.path);
    // copy code source module folder to target project
    const targetPath = resolve(config.app.rootDir, config.harmony.name, basename(plugin.rootPath));
    mkdirSync(targetPath, { recursive: true })
    copy(srcPath, targetPath);
  }
  
  await writeFile(pluginDependencePath, JSON.stringify(pluginInfoData, null, 2), { encoding: 'utf-8' });
  await writeFile(buildProfilePath, JSON.stringify(buildProfileInfoData, null, 2), { encoding: 'utf-8' });
  await writeFile(projectBuildProfilePath, JSON.stringify(projectBuildProfileInfoData, null, 2), { encoding: 'utf-8' });
}

async function findHarmonyPluginJsonEntry(
  plugins: Plugin[],
): Promise<PluginsJsonEntry[]> {
  const entries: PluginsJsonEntry[] = [];

  for (const plugin of plugins) {
    entries.push(...(await findHarmonyPluginModulesInPlugin(plugin)));
  }

  return entries;
}

async function findHarmonyPluginModulesInPlugin(
  plugin: Plugin,
): Promise<PluginsJsonEntry[]> {
  if (!plugin.harmony || getPluginType(plugin, platform) !== PluginType.Core) {
    return [];
  }

  const srcPath = resolve(plugin.rootPath, plugin.harmony.path);
  const pluginInfo = await readJSON(resolve(srcPath, 'oh-package.json5'));
  const moduleInfo = await readJSON(resolve(srcPath, 'src/main', 'module.json5'));
  return [{
    plugin: pluginInfo.name,
    pluginClass: moduleInfo.module.name + 'Plugin',
    module: moduleInfo.module.name,
    moduleAlias: pluginInfo.name,
  }];
}

async function getPluginsTask(config: Config) {
  return await runTask('Updating Harmony plugins', async () => {
    const allPlugins = await getPlugins(config, 'harmony');
    const harmonyPlugins = await getHarmonyPlugins(allPlugins);
    return harmonyPlugins;
  });
}
