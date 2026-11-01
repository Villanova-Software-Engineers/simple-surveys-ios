import Foundation

public enum APIEndpoint {
    case registerDevice
    case getSchedule
    case getSurvey(id: String)
    case listSurveys
    case submitResponse
    
    public var path: String {
        switch self {
        case .registerDevice:
            return "/api/notifications/devices"
        case .getSchedule:
            return "/api/notifications/schedule"
        case .getSurvey(let id):
            return "/api/surveys/\(id)"
        case .listSurveys:
            return "/api/surveys"
        case .submitResponse:
            return "/api/responses"
        }
    }
}
