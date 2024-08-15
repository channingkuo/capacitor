import { webview } from '@kit.ArkWeb';
import { uri } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';
import { CapacitorBridge } from './CapacitorBridge';
import { Capacitor } from './Capacitor';

type Context = common.UIAbilityContext;

@Component
export struct CapacitorWebView {
  private scheme: string = 'http';
  private host: string = 'localhost';

  private webViewController: webview.WebviewController = new webview.WebviewController();
  private context: Context = getContext() as Context;
  private javaScriptProxy: JavaScriptProxy = {
    object: new CapacitorBridge(this.webViewController),
    name: 'harmonyBridge',
    methodList: ['postMessage'],
    controller: this.webViewController
  }
  private capacitor = new Capacitor(this.context, this.webViewController);

  aboutToAppear(): void {
    webview.WebviewController.setWebDebuggingAccess(true);
  }

  build() {
    Web({ src: this.host, controller: this.webViewController })
      .fileAccess(true)
      .javaScriptAccess(true)
      .imageAccess(true)
      // http and https mixed use
      .mixedMode(MixedMode.All)
        // web localstorage accessible
      .domStorageAccess(true)
        // web location accessible
      .geolocationAccess(true)
      .darkMode(WebDarkMode.Auto)
        // web console
      .onConsole((event: OnConsoleEvent) => {
        console.log('⚡️ web console: ' + event.message.getMessage(),
          event.message.getSourceId(),
          event.message.getLineNumber()
        );
        return true;
      })
        // web resource load error
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        console.log('⚡️ web resource load error: ' + event.request.getRequestUrl());
      })
        // intercept
      .onInterceptRequest((event: OnInterceptRequestEvent) => {
        return this.onInterceptRequest(event.request);
      })
        // intercept prompt to show native prompt
      .onPrompt((event: OnPromptEvent) => {
        const message = event.message;
        const result = event.result;
        AlertDialog.show({
          title: $r('app.string.alert_btn_tips'),
          message: message,
          autoCancel: false,
          gridCount: 4,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: $r('app.string.alert_btn_cancel'),
            action: () => {
              result.handleCancel();
            }
          },
          secondaryButton: {
            enabled: true,
            defaultFocus: true,
            style: DialogButtonStyle.HIGHLIGHT,
            value: $r('app.string.alert_btn_ok'),
            action: () => {
              result.handleConfirm();
            }
          },
        })
        return false;
      })
        // intercept confirm to show native confirm
      .onConfirm((event: OnConfirmEvent) => {
        const message = event.message;
        const result = event.result;
        AlertDialog.show({
          title: $r('app.string.alert_btn_tips'),
          message: message,
          autoCancel: false,
          gridCount: 4,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: $r('app.string.alert_btn_cancel'),
            action: () => {
              result.handleCancel();
            }
          },
          secondaryButton: {
            enabled: true,
            defaultFocus: true,
            style: DialogButtonStyle.HIGHLIGHT,
            value: $r('app.string.alert_btn_ok'),
            action: () => {
              result.handleConfirm();
            }
          },
        })
        return false;
      })
        // intercept alert to show native alert
      .onAlert((event: OnAlertEvent) => {
        const message = event.message;
        const result = event.result;
        AlertDialog.show({
          title: $r('app.string.alert_btn_tips'),
          message: message,
          autoCancel: false,
          gridCount: 3,
          alignment: DialogAlignment.Center,
          confirm: {
            value: $r('app.string.alert_btn_ok'),
            defaultFocus: true,
            style: DialogButtonStyle.HIGHLIGHT,
            action: () => {
              result.handleConfirm();
            }
          }
        })
        return false;
      })
      .onControllerAttached(() => {
      })
        // inject native method into web
      .javaScriptProxy(this.javaScriptProxy)
        // web start loading
      .onPageBegin((event: OnPageBeginEvent) => {
        this.capacitor.registerPlugins();
      })
        // web end loading
      .onPageEnd((event: OnPageEndEvent) => {
      })
      .width('100%')
      .height('100%')
  }

  onInterceptRequest(request: WebResourceRequest): WebResourceResponse | null {
    console.log('⚡️ intercept request: ' + request.getRequestUrl());

    const requestHeaders = request.getRequestHeader();
    const requestUrl = request.getRequestUrl();
    const requestUri = new uri.URI(requestUrl);
    const filePath = requestUri.path;

    if (requestUrl.startsWith(this.buildServerUrl())) {
      const reserverFilePath = filePath === '/' ? 'www/index.html' : 'www' + filePath;
      console.log('⚡️ back proxy request to: resource://rawfile/' + reserverFilePath);

      const webResourceResponse = new WebResourceResponse();
      webResourceResponse.setResponseData($rawfile(reserverFilePath));
      webResourceResponse.setResponseMimeType(this.checkMimeType(reserverFilePath, requestHeaders));
      webResourceResponse.setResponseEncoding('UTF-8');
      webResourceResponse.setResponseCode(200);
      return webResourceResponse;
    }
    return null;
  }

  buildServerUrl(): string {
    return this.scheme + '://' + this.host
  }

  checkMimeType(filePath: string, requestHeaders: Array<Header>): string {
    let mimeType = 'text/html';
    filePath = filePath.toLowerCase();
    if (filePath.endsWith('.html')) {
      mimeType = 'text/html';
    } else if (filePath.endsWith('.css')) {
      mimeType = 'text/css';
    } else if (filePath.endsWith('.js') || filePath.endsWith('.mjs')) {
      mimeType = 'application/javascript';
    } else if (filePath.endsWith('.svg')) {
      mimeType = 'image/svg+xml';
    } else if (filePath.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (filePath.endsWith('.jpg')) {
      mimeType = 'image/jpeg';
    } else if (filePath.endsWith('.map')) {
      mimeType = 'application/js';
    } else if (filePath.endsWith('.json')) {
      mimeType = 'application/json';
    } else if (filePath.endsWith('.bin')) {
      mimeType = 'application/octet-stream';
    } else if (filePath.endsWith('.wasm')) {
      mimeType = 'application/wasm';
    } else {
      mimeType = 'text/html';
    }
    return mimeType;
  }
}
