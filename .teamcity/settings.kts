// .teamcity/settings.kts
// TeamCity Kotlin DSL Configuration Example for Mergify Integration
//
// This configuration sets up TeamCity builds that integrate with Mergify
// through GitHub's commit status API.

import jetbrains.buildServer.configs.kotlin.*
import jetbrains.buildServer.configs.kotlin.buildFeatures.commitStatusPublisher
import jetbrains.buildServer.configs.kotlin.buildSteps.script
import jetbrains.buildServer.configs.kotlin.triggers.vcs
import jetbrains.buildServer.configs.kotlin.vcs.GitVcsRoot

version = "2024.03"

project {
    vcsRoot(GitHubRepository)
    
    buildType(Tests)
    buildType(Lint)
    buildType(Build)
    buildType(MergifyValidation)
}

// VCS Root Configuration
object GitHubRepository : GitVcsRoot({
    name = "GitHub Repository"
    url = "https://github.com/your-org/your-repo.git"
    branch = "refs/heads/main"
    branchSpec = """
        +:refs/heads/*
        +:refs/pull/*/head
    """.trimIndent()
    
    authMethod = password {
        userName = "your-github-username"
        password = "credentialsJSON:github-token"
    }
    
    param("oauthProviderId", "PROJECT_EXT_2")
})

// Tests Build Configuration
object Tests : BuildType({
    name = "Tests"
    description = "Run unit and integration tests"
    
    vcs {
        root(GitHubRepository)
    }
    
    steps {
        script {
            name = "Install Dependencies"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm ci
            """.trimIndent()
        }
        
        script {
            name = "Run Unit Tests"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run test:unit
            """.trimIndent()
        }
        
        script {
            name = "Run Integration Tests"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run test:integration
            """.trimIndent()
        }
    }
    
    features {
        commitStatusPublisher {
            vcsRootExtId = "${GitHubRepository.id}"
            publisher = github {
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "credentialsJSON:github-token"
                }
            }
        }
    }
    
    triggers {
        vcs {
            branchFilter = """
                +:pull/*
                +:refs/heads/main
            """.trimIndent()
        }
    }
    
    artifactRules = """
        coverage/** => coverage.zip
        test-results/** => test-results.zip
    """.trimIndent()
    
    params {
        param("teamcity.build.timeout", "30")
    }
})

// Lint Build Configuration
object Lint : BuildType({
    name = "Lint"
    description = "Run code linters and formatters"
    
    vcs {
        root(GitHubRepository)
    }
    
    steps {
        script {
            name = "Install Dependencies"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm ci
            """.trimIndent()
        }
        
        script {
            name = "Run ESLint"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run lint
            """.trimIndent()
        }
        
        script {
            name = "Check Code Formatting"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run format:check
            """.trimIndent()
        }
    }
    
    features {
        commitStatusPublisher {
            vcsRootExtId = "${GitHubRepository.id}"
            publisher = github {
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "credentialsJSON:github-token"
                }
            }
        }
    }
    
    triggers {
        vcs {
            branchFilter = """
                +:pull/*
                +:refs/heads/main
            """.trimIndent()
        }
    }
    
    params {
        param("teamcity.build.timeout", "10")
    }
})

// Build Configuration
object Build : BuildType({
    name = "Build"
    description = "Build the application"
    
    vcs {
        root(GitHubRepository)
    }
    
    steps {
        script {
            name = "Install Dependencies"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm ci
            """.trimIndent()
        }
        
        script {
            name = "Type Check"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run type-check
            """.trimIndent()
        }
        
        script {
            name = "Build Application"
            dockerImage = "node:20-alpine"
            scriptContent = """
                npm run build
            """.trimIndent()
        }
    }
    
    features {
        commitStatusPublisher {
            vcsRootExtId = "${GitHubRepository.id}"
            publisher = github {
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "credentialsJSON:github-token"
                }
            }
        }
    }
    
    triggers {
        vcs {
            branchFilter = """
                +:pull/*
                +:refs/heads/main
            """.trimIndent()
        }
    }
    
    artifactRules = """
        dist/** => build.zip
    """.trimIndent()
    
    params {
        param("teamcity.build.timeout", "20")
    }
})

// Mergify Validation Build Configuration
object MergifyValidation : BuildType({
    name = "Mergify Validation"
    description = "Validate Mergify configuration"
    
    vcs {
        root(GitHubRepository)
        checkoutMode = CheckoutMode.ON_AGENT
        checkoutDir = "."
    }
    
    steps {
        script {
            name = "Validate Mergify Configuration"
            dockerImage = "python:3.11-alpine"
            scriptContent = """
                #!/bin/sh
                set -e
                
                echo "Installing validation tools..."
                apk add --no-cache git
                pip install --no-cache-dir yamllint mergify-cli
                
                echo "Validating YAML syntax..."
                yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" .mergify.yml
                
                echo "Validating Mergify configuration..."
                mergify validate .mergify.yml
                
                echo "✅ Mergify configuration is valid!"
            """.trimIndent()
        }
    }
    
    features {
        commitStatusPublisher {
            vcsRootExtId = "${GitHubRepository.id}"
            publisher = github {
                githubUrl = "https://api.github.com"
                authType = personalToken {
                    token = "credentialsJSON:github-token"
                }
            }
        }
    }
    
    triggers {
        vcs {
            branchFilter = "+:pull/*"
            triggerRules = "+:.mergify.yml"
        }
    }
    
    params {
        param("teamcity.build.timeout", "5")
    }
})
