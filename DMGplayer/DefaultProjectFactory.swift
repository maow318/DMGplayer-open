//
//  DefaultProjectFactory.swift
//  DMGplayer
//

import Foundation

nonisolated enum DefaultProjectFactory {
    static func project(
        for applicationURL: URL,
        metadata: AppBundleMetadata? = nil,
        volumeIconData: Data? = nil
    ) -> DMGProject {
        let metadata = metadata ?? AppBundleMetadata.plistMetadata(at: applicationURL)
        var project = DMGProject()
        project.volumeName = metadata.displayName
        project.volumeIconData = volumeIconData
        project.windowWidth = 600
        project.windowHeight = 360
        project.iconSize = 96
        project.background = .color
        project.backgroundColor = CodableColor(red: 0.95, green: 0.96, blue: 0.98)
        var application = ContentItem()
        application.kind = .file
        application.sourcePath = applicationURL.path
        application.name = applicationURL.lastPathComponent
        application.position = CGPoint(x: 150, y: 180)

        var applicationsLink = ContentItem()
        applicationsLink.kind = .applicationsLink
        applicationsLink.name = "Applications"
        applicationsLink.position = CGPoint(x: 450, y: 180)
        project.items = [application, applicationsLink]
        return project
    }
}
