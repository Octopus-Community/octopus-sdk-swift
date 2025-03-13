//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GrpcModels

enum MockData {
    static var posts: [[Com_Octopuscommunity_OctoObject]] { [
        [
            .with {
                $0.createdAt = .since(.seconds(1))
                $0.id = "post1"
                $0.parentID = "topicTechnology"
                $0.createdBy = .with {
                    $0.profileID = "jd"
                    $0.nickname = "John Doe"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "AI Revolutionizes Healthcare with Unprecedented Advancements"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(2))
                $0.id = "post2"
                $0.parentID = "topicScience"
                $0.createdBy = .with {
                    $0.profileID = "ec"
                    $0.nickname = "Emily Clark"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "New Discovery in Quantum Physics Challenges Current Theories"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(2))
                $0.id = "post3"
                $0.parentID = "topicSport"
                $0.createdBy = .with {
                    $0.profileID = "mj"
                    $0.nickname = "Michael Jordan"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Major Upset in Tennis as Underdog Wins Grand Slam"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(15), .seconds(30))
                $0.id = "post4"
                $0.parentID = "topicMovies"
                $0.createdBy = .with {
                    $0.profileID = "sm"
                    $0.nickname = "Sophia Miller"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The latest action movie has become the highest-grossing film of the year, surpassing all expectations."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.minutes(59), .seconds(45))
                $0.id = "post5"
                $0.parentID = "topicSport"
                $0.createdBy = .with {
                    $0.profileID = "vs"
                    $0.nickname = "Valentin Salmon"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "En grande difficulté économique, la station pourrait être sauvée par un projet porté par un ascenseur valléene et une commauté réunie grace à Octopus Community"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.hours(1), .minutes(4))
                $0.id = "post6"
                $0.parentID = "topicJobs"
                $0.createdBy = .with {
                    $0.profileID = "sw"
                    $0.nickname = "Scott Wright"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The Glen Sannox has suffered a further problem after sea trials came to a halt following an inadvertent blackout."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.hours(1), .minutes(45))
                $0.id = "post7"
                $0.parentID = "topicEducation"
                $0.createdBy = .with {
                    $0.profileID = "rl"
                    $0.nickname = "Rachel Lee"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Increased demand for flexible learning solutions has led to a boom in online education platforms."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.hours(10), .seconds(10))
                $0.id = "post8"
                $0.parentID = "topicFinance"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Investors are facing challenges as market fluctuations show no signs of stabilizing."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.hours(20))
                $0.id = "post9"
                $0.parentID = "topicTravel"
                $0.createdBy = .with {
                    $0.profileID = "aj"
                    $0.nickname = "Amanda Johnson"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "These are the must-visit places for thrill-seekers looking for their next big adventure."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.days(1), .hours(2))
                $0.id = "post10"
                $0.parentID = "topicFood"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The rise of plant-based diets has led to an increase in vegan restaurant options and recipes."
                    }
                }
            },
        ],
        [
            .with {
                $0.createdAt = .since(.days(1), .hours(3))
                $0.id = "post11"
                $0.parentID = "topicMusic"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The latest album from a popular indie band has achieved international success, topping charts worldwide."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.days(2))
                $0.id = "post12"
                $0.parentID = "topicFashion"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Eco-conscious fashion is becoming a major movement, with designers focusing on sustainability."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.days(10))
                $0.id = "post13"
                $0.parentID = "topicHealth"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Researchers have found significant mental health benefits for those practicing mindfulness meditation regularly."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.days(28))
                $0.id = "post14"
                $0.parentID = "topicLifestyle"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "More people are embracing minimalism, focusing on decluttering and simplifying their lives."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.days(30))
                $0.id = "post15"
                $0.parentID = "topicEnvironment"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Countries worldwide are intensifying efforts to combat climate change in light of rising global temperatures."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.months(1), .days(2), .hours(2))
                $0.id = "post16"
                $0.parentID = "topicPolitics"
                $0.createdBy = .with {
                    $0.profileID = "og"
                    $0.nickname = "Oliver Green"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Lawmakers are introducing new policies designed to close the widening gap between the rich and the poor."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.months(2))
                $0.id = "post17"
                $0.parentID = "topicRealEstate"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Despite economic uncertainties, the housing market continues to show resilience in many regions."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.months(3))
                $0.id = "post18"
                $0.parentID = "topicAutomotive"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "EVs are steadily increasing their market share as more consumers make the switch to environmentally friendly cars."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.months(3))
                $0.id = "post19"
                $0.parentID = "topicGaming"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Upcoming Game Release Generates Massive Hype"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.months(10))
                $0.id = "post20"
                $0.parentID = "topicSport"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Martin Short’s athleticism was put to the test in Tuesday’s episode of “Only Murders in the Building” as Oliver volunteers to reenact how Sazz Pataki’s killer was able to murder the Brazzos stunt double, clean up the crime scene and bring her down to the incinerator all in 12 minutes."
                    }
                }
            },
        ],
        [
            .with {
                $0.createdAt = .since(.years(1), .hours(1))
                $0.id = "post21"
                $0.parentID = "topicFood"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "'The Last of Us’ zombie spider fungus found in Scotland"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.years(1), .months(1))
                $0.id = "post22"
                $0.parentID = "topicLifestyle"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Two of the best-known figures on the Scottish commercial property scene have signalled hope that a brighter future can be secured for Glasgow’s ageing office stock, as debate continues to rage over how best to reverse the declining fortunes of the city centre."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.years(1), .months(10))
                $0.id = "post23"
                $0.parentID = "topicJobs"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "Dobbies to shut two stores in Scotland as part of restructuring plan"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.years(1), .months(10))
                $0.id = "post24"
                $0.parentID = "topicLifestyle"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The village of Ballater in Royal Deeside may be famous for family connections, but this is a village that provides VIP hospitality for all"
                    }
                }
            },
            .with {
                $0.createdAt = .since(.years(2))
                $0.id = "post25"
                $0.parentID = "topicJobs"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The Glen Sannox has suffered a further problem after sea trials came to a halt following an inadvertent blackout."
                    }
                }
            },
            .with {
                $0.createdAt = .since(.years(11))
                $0.id = "post26"
                $0.parentID = "topicJobs"
                $0.createdBy = .with {
                    $0.profileID = "db"
                    $0.nickname = "David Brown"
                }
                $0.content = .with {
                    $0.post = .with {
                        $0.text = "The Glen Sannox has suffered a further problem after sea trials came to a halt following an inadvertent blackout."
                    }
                }
            },
        ]
    ] }
}
