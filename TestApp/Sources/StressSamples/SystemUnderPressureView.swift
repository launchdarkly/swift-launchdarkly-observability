import SwiftUI

struct SystemUnderPressureView: View {
    @StateObject private var cpuLoadGenerator = CpuLoadGenerator()
    @StateObject private var pressurizer = MemoryPressurizer()
    @State private var isProcessing = false
    @State private var cpuLoad: Double = 0.5
    @State private var cpuThreads: Double = 1.0
    
    var body: some View {
        VStack(spacing: 34.0) {
            Label {
                Text(pressurizer.memoryPressureLevel.name)
                    .font(.headline)
                    .padding()
            } icon: {
                Image(systemName: "memorychip")
            }
            ForEach(MemoryPressurizer.MemoryPressureLoadSize.allCases, id: \.self) { size in
                Button {
                    pressurizer.pressurize(by: size)
                } label: {
                    Text("Increase memory usage by \(size.megabytes) MB")
                }
            }
            Divider()
            Text("CPU load: \(Int(cpuLoad * 100)) %")
                .font(.largeTitle)
                .foregroundColor(cpuLoad > 0.75 ? .red : cpuLoad > 0.50 ? .yellow : .blue)
            Slider(value: $cpuLoad, in: 0...1, step: 0.1) {
                Text("CPU load")
            } minimumValueLabel: {
                Text("0 %")
            } maximumValueLabel: {
                Text("100 %")
            }
            .padding(.horizontal)
            .disabled(isProcessing)
            Text("CPU threads: \(cpuThreads)")
                .font(.largeTitle)
            Slider(value: $cpuThreads, in: 1...64, step: 1) {
                Text("CPU load")
            } minimumValueLabel: {
                Text("1")
            } maximumValueLabel: {
                Text("64")
            }
            .padding(.horizontal)
            .disabled(isProcessing)
            Toggle(isProcessing ? "Stop processing" : "Start processing", isOn: $isProcessing)
                .padding(.horizontal)
                .task(id: isProcessing) {
                    if isProcessing {
                        cpuLoadGenerator.startLoad(
                            threads: Int(cpuThreads),
                            load: cpuLoad
                        )
                    } else {
                        cpuLoadGenerator.stopLoad()
                    }
                }
        }
        .onDisappear {
            pressurizer.release()
        }
    }
}
