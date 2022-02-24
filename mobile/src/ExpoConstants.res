type repository = {url: string}
type extra = {commitSha: option<string>, repository: repository}
type manifest = {name: string, version: string, extra: extra}
type constants = {manifest: manifest}
@val @module("expo-constants") external constants: constants = "default"
