import { CapacitorWebView } from 'capacitor'

@Entry
@Component
struct Index {
  build() {
    Column() {
      CapacitorWebView()
    }
  }
}