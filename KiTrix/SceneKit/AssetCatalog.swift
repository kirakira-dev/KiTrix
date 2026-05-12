import Foundation


struct AssetCatalog {
    
    static let assetsPath = Bundle.main.resourcePath ?? ""
    static let extractedModelsPath = "\(assetsPath)/Assets/Models"
    
    
    enum PlayerVariant: String {
        case player00 = "Player00"
        case player01 = "Player01"
        case player02 = "Player02"
        
        var modelPath: String {
            return "\(AssetCatalog.extractedModelsPath)/\(rawValue).fbx"
        }
    }
    
    
    struct WeaponModel {
        let name: String
        let modelPath: String
        let weaponClass: WeaponClass
    }
    
    static let weaponModels: [WeaponModel] = [
        WeaponModel(name: "Wmn_Shooter_Blaze", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Blaze.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Expert", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Expert.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_First", modelPath: "\(extractedModelsPath)/Wmn_Shooter_First.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Flash", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Flash.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Gravity", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Gravity.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Heavy", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Heavy.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Long", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Long.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Normal", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Normal.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_NormalB", modelPath: "\(extractedModelsPath)/Wmn_Shooter_NormalB.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_NormalT", modelPath: "\(extractedModelsPath)/Wmn_Shooter_NormalT.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_QuickLong", modelPath: "\(extractedModelsPath)/Wmn_Shooter_QuickLong.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_QuickMiddle", modelPath: "\(extractedModelsPath)/Wmn_Shooter_QuickMiddle.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Short", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Short.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_Triple", modelPath: "\(extractedModelsPath)/Wmn_Shooter_Triple.obj", weaponClass: .shooter),
        WeaponModel(name: "Wmn_Shooter_TripleMiddle", modelPath: "\(extractedModelsPath)/Wmn_Shooter_TripleMiddle.obj", weaponClass: .shooter),
        
        WeaponModel(name: "Wmn_Blaster_Long", modelPath: "\(extractedModelsPath)/Wmn_Blaster_Long.obj", weaponClass: .blaster),
        WeaponModel(name: "Wmn_Blaster_Light", modelPath: "\(extractedModelsPath)/Wmn_Blaster_Light.obj", weaponClass: .blaster),
        WeaponModel(name: "Wmn_Blaster_Middle", modelPath: "\(extractedModelsPath)/Wmn_Blaster_Middle.obj", weaponClass: .blaster),
        WeaponModel(name: "Wmn_Blaster_Short", modelPath: "\(extractedModelsPath)/Wmn_Blaster_Short.obj", weaponClass: .blaster),
        
        WeaponModel(name: "Wmn_Brush_Heavy", modelPath: "\(extractedModelsPath)/Wmn_Brush_Heavy.obj", weaponClass: .brush),
        WeaponModel(name: "Wmn_Brush_Mini", modelPath: "\(extractedModelsPath)/Wmn_Brush_Mini.obj", weaponClass: .brush),
        WeaponModel(name: "Wmn_Brush_Normal", modelPath: "\(extractedModelsPath)/Wmn_Brush_Normal.obj", weaponClass: .brush),
        
        WeaponModel(name: "Wmn_Charger_Light", modelPath: "\(extractedModelsPath)/Wmn_Charger_Light.obj", weaponClass: .charger),
        WeaponModel(name: "Wmn_Charger_Long", modelPath: "\(extractedModelsPath)/Wmn_Charger_Long.obj", weaponClass: .charger),
        WeaponModel(name: "Wmn_Charger_NormalT", modelPath: "\(extractedModelsPath)/Wmn_Charger_NormalT.obj", weaponClass: .charger),
        WeaponModel(name: "Wmn_Charger_Quick", modelPath: "\(extractedModelsPath)/Wmn_Charger_Quick.obj", weaponClass: .charger),
        
        WeaponModel(name: "Wmn_Roller_BrushNormal", modelPath: "\(extractedModelsPath)/Wmn_Roller_BrushNormal.obj", weaponClass: .roller),
        
        WeaponModel(name: "Wmn_Slosher_Bathtub", modelPath: "\(extractedModelsPath)/Wmn_Slosher_Bathtub.obj", weaponClass: .slosher),
        WeaponModel(name: "Wmn_Slosher_Diffusion", modelPath: "\(extractedModelsPath)/Wmn_Slosher_Diffusion.obj", weaponClass: .slosher),
        WeaponModel(name: "Wmn_Slosher_Double", modelPath: "\(extractedModelsPath)/Wmn_Slosher_Double.obj", weaponClass: .slosher),
        
        WeaponModel(name: "Wmn_Spinner_Downpour", modelPath: "\(extractedModelsPath)/Wmn_Spinner_Downpour.obj", weaponClass: .spinner),
        WeaponModel(name: "Wmn_Spinner_HyperShort", modelPath: "\(extractedModelsPath)/Wmn_Spinner_HyperShort.obj", weaponClass: .spinner),
        WeaponModel(name: "Wmn_Spinner_HyperT", modelPath: "\(extractedModelsPath)/Wmn_Spinner_HyperT.obj", weaponClass: .spinner),
        WeaponModel(name: "Wmn_Spinner_QuickT", modelPath: "\(extractedModelsPath)/Wmn_Spinner_QuickT.obj", weaponClass: .spinner),
        WeaponModel(name: "Wmn_Spinner_Serein", modelPath: "\(extractedModelsPath)/Wmn_Spinner_Serein.obj", weaponClass: .spinner),
        WeaponModel(name: "Wmn_Spinner_StandardT", modelPath: "\(extractedModelsPath)/Wmn_Spinner_StandardT.obj", weaponClass: .spinner),
        
        WeaponModel(name: "Wmn_Stringer_Normal", modelPath: "\(extractedModelsPath)/Wmn_Stringer_Normal.obj", weaponClass: .stringer),
        WeaponModel(name: "Wmn_Stringer_Short", modelPath: "\(extractedModelsPath)/Wmn_Stringer_Short.obj", weaponClass: .stringer),
        WeaponModel(name: "Wmn_Stringer_Coop", modelPath: "\(extractedModelsPath)/Wmn_Stringer_Coop.obj", weaponClass: .stringer),
        
        WeaponModel(name: "Wmn_Shelter_Compact", modelPath: "\(extractedModelsPath)/Wmn_Shelter_Compact.obj", weaponClass: .shelter),
        WeaponModel(name: "Wmn_Shelter_Focus", modelPath: "\(extractedModelsPath)/Wmn_Shelter_Focus.obj", weaponClass: .shelter),
        WeaponModel(name: "Wmn_Shelter_Normal", modelPath: "\(extractedModelsPath)/Wmn_Shelter_Normal.obj", weaponClass: .shelter),
        WeaponModel(name: "Wmn_Shelter_Wide", modelPath: "\(extractedModelsPath)/Wmn_Shelter_Wide.obj", weaponClass: .shelter),
        
        WeaponModel(name: "Wmn_Saber_Heavy", modelPath: "\(extractedModelsPath)/Wmn_Saber_Heavy.obj", weaponClass: .saber),
        WeaponModel(name: "Wmn_Saber_Light", modelPath: "\(extractedModelsPath)/Wmn_Saber_Light.obj", weaponClass: .saber),
        WeaponModel(name: "Wmn_Saber_Normal", modelPath: "\(extractedModelsPath)/Wmn_Saber_Normal.obj", weaponClass: .saber),
    ]
    
    static func weaponModel(forTableIndex index: Int) -> WeaponModel? {
        let wClass = WeaponModelLoader.weaponClass(fromTableIndex: index)
        
        let matching = weaponModels.filter { $0.weaponClass == wClass }
        if matching.isEmpty { return nil }
        
        return matching[index % matching.count]
    }
    
    
    struct ClothingModel {
        let name: String
        let modelPath: String
        let category: ClothingCategory
    }
    
    enum ClothingCategory {
        case head, body, shoes
    }
    
    static let clothingModels: [ClothingModel] = [
        ClothingModel(name: "Btm_001_F", modelPath: "\(extractedModelsPath)/Btm_001_F.obj", category: .shoes),
        ClothingModel(name: "Btm_001_M", modelPath: "\(extractedModelsPath)/Btm_001_M.obj", category: .shoes),
        ClothingModel(name: "Btm_003_F", modelPath: "\(extractedModelsPath)/Btm_003_F.obj", category: .shoes),
        ClothingModel(name: "Btm_003_M", modelPath: "\(extractedModelsPath)/Btm_003_M.obj", category: .shoes),
        ClothingModel(name: "Clt_JKT059", modelPath: "\(extractedModelsPath)/Clt_JKT059.obj", category: .body),
        ClothingModel(name: "Clt_SHT022", modelPath: "\(extractedModelsPath)/Clt_SHT022.obj", category: .body),
        ClothingModel(name: "Clt_SHT023", modelPath: "\(extractedModelsPath)/Clt_SHT023.obj", category: .body),
    ]


    static let headgearModels: [ClothingModel] = [
        ClothingModel(name: "Hed_CAP000", modelPath: "\(extractedModelsPath)/Hed_CAP000.obj", category: .head),
        ClothingModel(name: "Hed_CAP001", modelPath: "\(extractedModelsPath)/Hed_CAP001.obj", category: .head),
        ClothingModel(name: "Hed_CAP002", modelPath: "\(extractedModelsPath)/Hed_CAP002.obj", category: .head),
        ClothingModel(name: "Hed_AMB000", modelPath: "\(extractedModelsPath)/Hed_AMB000.obj", category: .head),
        ClothingModel(name: "Hed_AMB001", modelPath: "\(extractedModelsPath)/Hed_AMB001.obj", category: .head),
        ClothingModel(name: "Hed_AMB002", modelPath: "\(extractedModelsPath)/Hed_AMB002.obj", category: .head),
    ]
}
