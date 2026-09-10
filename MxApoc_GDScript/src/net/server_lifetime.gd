class_name ServerLifetime
extends RefCounted

## 权威服存活策略。第一版只用 owner：创建者离开即关服。
const OWNER := "owner"
const PERSISTENT := "persistent"
