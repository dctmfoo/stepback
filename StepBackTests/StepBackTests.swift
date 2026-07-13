import Testing
@testable import StepBack

@Test
func appModuleLoads() {
    #expect(String(describing: AppShellView.self) == "AppShellView")
}
