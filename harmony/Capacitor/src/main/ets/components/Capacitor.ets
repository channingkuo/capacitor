import { webview } from '@kit.ArkWeb';
import { JSExport } from './JSExport';
import common from '@ohos.app.ability.common';

type Context = common.UIAbilityContext;

export class Capacitor {
  private context: Context;
  private webViewController: webview.WebviewController;

  constructor(context: Context, webViewController: webview.WebviewController) {
    this.context = context;
    this.webViewController = webViewController;
  }

  registerPlugins(): void {
    Promise.all([
      JSExport.getGlobalJS(),
      JSExport.getBridgeJS(this.context),
      JSExport.getPluginJS(this.context)
    ]).then((res: string[]) => {
      res.forEach(script => this.webViewController.runJavaScript(script));
    })
  }
}