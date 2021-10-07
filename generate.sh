#!/bin/bash
: "${GIT_TARGET_REVISION:='HEAD'}"

# checks
[[ $# != 2 ]] && echo "Usage: $0 <repo> <bundleVersion>" && exit 1
_REPO=$1
_BUNDLE_VERSION=$2

main() {
    env | sort
    
    [[ ${CLONE_REPO} == "true" ]] && {
        # if repoURL contains exactly 1 / (org/repo handle), prepend the github prefix
        [[ "${_REPO}" =~ ^[^\/]*\/[^\/]*$ ]] && _REPO="https://github.com/${_REPO}.git"
        echo Cloning the repo ${_REPO}..
        git clone ${_REPO}
        cd "$(basename "$_" .git)"
        git reset --hard ${GIT_TARGET_REVISION} 2> /dev/null || git reset --hard origin/${GIT_TARGET_REVISION}
    }
    [[ ! -z "${LOCAL_PATH}" ]] && cd ${LOCAL_PATH}
    export REPO_ROOT=${PWD}
    echo PWD is ${PWD}

    [[ ${VALIDATE_KUSTOMIZE} == "true" ]] && {
            pushd config/manifests/
            kustomize build || exit 1
            popd
    }

    # pre-generate hook
    [[ ! -z "${PRE_GENERATE_HOOK}" ]] && {
        echo Running pre-generate hook..
        [[ ! -z "${PREPARE_HELM_COMMAND}" ]] && echo PREPARE_HELM_COMMAND: "${PREPARE_HELM_COMMAND}"
        [[ ! -z "${HELM_COMMAND}" ]] && echo HELM_COMMAND: "${HELM_COMMAND}"
        echo ${PRE_GENERATE_HOOK}
        set -x
        eval ${PRE_GENERATE_HOOK}
        set +x
    }

    # this will create the bundle
    BUNDLE_VERSION=${_BUNDLE_VERSION} make -f /Makefile bundle-generate

    # post-generate hook
    [[ ! -z "${POST_GENERATE_HOOK}" ]] && {
        echo Running post-generate hook..
        echo ${POST_GENERATE_HOOK}
        set -x
        eval ${POST_GENERATE_HOOK}
        set +x
    }

    # optionally run the validation
    [[ ${VALIDATE_BUNDLE} == "true" ]] && {
        BUNDLE_VERSION=${_BUNDLE_VERSION} make -f /Makefile bundle-validate || exit 1
    }

    # print the result
    TREE_OUTPUT="$(tree ./bundle)"
    echo -e "\n\n\n\nDone. Here is the result:\n=========================\n\n${TREE_OUTPUT}"
    CSV_OUTPUT="$(cat bundle/manifests/*.clusterserviceversion.yaml)"
    echo -e "\n\n\n\nCSV:\n=========================\n\n${CSV_OUTPUT}"
    
    TREE_OUTPUT="$(escape $TREE_OUTPUT)"
    CSV_OUTPUT="$(escape $CSV_OUTPUT)"
    echo "::set-output name=treeOutput::$TREE_OUTPUT"
    echo "::set-output name=csvOutput::$CSV_OUTPUT"
}

escape(){
    [[ $# != 1 ]] && echo "Usage: $0 <arg>" && exit 1
    local _P=$1
    _P="${_P//'%'/'%25'}"
    _P="${_P//$'\n'/'%0A'}"
    _P="${_P//$'\r'/'%0D'}"
    echo ${_P}
}

main $@