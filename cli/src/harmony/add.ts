import c from '../colors';
import { runTask } from '../common';
import type { Config } from '../definitions';
import { extractTemplate } from '../util/template';

export async function addHarmony(config: Config): Promise<void> {
  await runTask(
    `Adding native harmony project in ${c.strong(config.harmony.platformDir)}`,
    async () => {
      return extractTemplate(
        config.cli.assets.harmony.platformTemplateArchiveAbs,
        config.harmony.platformDirAbs,
      );
    },
  );
}
