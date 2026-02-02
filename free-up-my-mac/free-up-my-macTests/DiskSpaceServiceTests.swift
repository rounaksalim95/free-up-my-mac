import Testing
import Foundation
@testable import free_up_my_mac

@Suite("DiskSpaceService Tests")
struct DiskSpaceServiceTests {

    // MARK: - Test 1: Get Disk Usage Returns Valid Data

    @Test("Get disk usage returns valid data")
    func testGetDiskUsage_ReturnsValidData() async throws {
        let service = DiskSpaceService()

        let usage = try await service.getDiskUsage()

        #expect(usage.totalBytes > 0)
        #expect(usage.usedBytes > 0)
        #expect(usage.freeBytes >= 0)
        #expect(usage.usedBytes <= usage.totalBytes)
    }

    // MARK: - Test 2: Usage Percentage Is Between 0 and 1

    @Test("Usage percentage is between 0 and 1")
    func testUsagePercentage_IsBetweenZeroAndOne() async throws {
        let service = DiskSpaceService()

        let usage = try await service.getDiskUsage()

        #expect(usage.usedPercentage >= 0)
        #expect(usage.usedPercentage <= 1)
    }

    // MARK: - Test 3: Free Percentage Is Complement Of Used

    @Test("Free percentage is complement of used percentage")
    func testFreePercentage_IsComplementOfUsed() async throws {
        let service = DiskSpaceService()

        let usage = try await service.getDiskUsage()

        let sum = usage.usedPercentage + usage.freePercentage
        #expect(abs(sum - 1.0) < 0.0001) // Allow for floating point imprecision
    }

    // MARK: - Test 4: Usage Level Normal

    @Test("Usage level is normal when under 70%")
    func testUsageLevel_Normal() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 600
        )

        #expect(usage.usageLevel == .normal)
    }

    // MARK: - Test 5: Usage Level Warning

    @Test("Usage level is warning when between 70% and 90%")
    func testUsageLevel_Warning() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 800
        )

        #expect(usage.usageLevel == .warning)
    }

    // MARK: - Test 6: Usage Level Critical

    @Test("Usage level is critical when over 90%")
    func testUsageLevel_Critical() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 950
        )

        #expect(usage.usageLevel == .critical)
    }

    // MARK: - Test 7: Usage Level At Boundary 70%

    @Test("Usage level at 70% boundary is warning")
    func testUsageLevel_AtBoundary70() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 700
        )

        #expect(usage.usageLevel == .warning)
    }

    // MARK: - Test 8: Usage Level At Boundary 90%

    @Test("Usage level at 90% boundary is critical")
    func testUsageLevel_AtBoundary90() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 900
        )

        #expect(usage.usageLevel == .critical)
    }

    // MARK: - Test 9: Zero Total Bytes Returns Zero Percentage

    @Test("Zero total bytes returns zero percentage")
    func testZeroTotalBytes_ReturnsZeroPercentage() async throws {
        let usage = DiskSpaceService.DiskUsage(
            totalBytes: 0,
            usedBytes: 0
        )

        #expect(usage.usedPercentage == 0)
        #expect(usage.freePercentage == 1.0)
    }

    // MARK: - Test 10: DiskUsage Equatable

    @Test("DiskUsage is equatable")
    func testDiskUsage_Equatable() async throws {
        let usage1 = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 500
        )

        let usage2 = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 500
        )

        let usage3 = DiskSpaceService.DiskUsage(
            totalBytes: 1000,
            usedBytes: 600
        )

        #expect(usage1 == usage2)
        #expect(usage1 != usage3)
    }

    // MARK: - Test 11: Get Important Disk Usage

    @Test("Get important disk usage returns valid data")
    func testGetDiskUsageImportant_ReturnsValidData() async throws {
        let service = DiskSpaceService()

        let usage = try await service.getDiskUsageImportant()

        #expect(usage.totalBytes > 0)
        #expect(usage.usedBytes > 0)
        #expect(usage.freeBytes >= 0)
    }
}
