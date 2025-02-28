//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

extension MockData {
    static var topics: [[Com_Octopuscommunity_OctoObject]] { [
        [
            .with {
                $0.createdAt = .since(.seconds(1))
                $0.id = "topicTechnology"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Technology"
                        $0.description_p = "Technology topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicScience"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Science"
                        $0.description_p = "Science topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicSport"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Sport"
                        $0.description_p = "Sport topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicMovies"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Movies"
                        $0.description_p = "Movies topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicJobs"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Jobs"
                        $0.description_p = "Jobs topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicEducation"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Education"
                        $0.description_p = "Education topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicFinance"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Finance"
                        $0.description_p = "Finance topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicTravel"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Travel"
                        $0.description_p = "Travel topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicFood"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Food"
                        $0.description_p = "Food topic"
                    }
                }
            },
        ],
        [
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicMusic"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Music"
                        $0.description_p = "Music topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicFashion"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Fashion"
                        $0.description_p = "Fashion topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicHealth"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Health"
                        $0.description_p = "Health topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicLifestyle"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Lifestyle"
                        $0.description_p = "Lifestyle topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicEnvironment"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Environment"
                        $0.description_p = "Environment topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicPolitics"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Politics"
                        $0.description_p = "Politics topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicRealEstate"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Real Estate"
                        $0.description_p = "Real Estate topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicAutomotive"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Automotive"
                        $0.description_p = "Automotive topic"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(1))
                $0.id = "topicGaming"
                $0.parentID = "topics"
                $0.createdBy = .with {
                    $0.profileID = "octopus"
                    $0.nickname = "Octopus"
                }
                $0.content = .with {
                    $0.topic = .with {
                        $0.name = "Gaming"
                        $0.description_p = "Gaming topic"
                    }
                }
            },
        ]
    ] }
}
