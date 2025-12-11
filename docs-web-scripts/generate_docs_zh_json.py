import json
import os
from pathlib import Path

import yaml


def translate_with_yaml(page):
    if page["body"]["kind"] in ["func", "type", "group", "category"]:
        route = page["route"][:-1] if page["route"].endswith("/") else page["route"]
        assert route.startswith("/docs/reference/")
        if page["body"]["kind"] == "category":
            path = ["category"] + route[len("/docs/reference/") :].split("/")
        else:
            path = route[len("/docs/reference/") :].split("/")
        assert len(path) == 2, str(path) + " " + route

        # without quotes and with indent
        zh_path = "docs/i18n/" + path[0] + "/" + path[1] + "-zh.yaml"
        if os.path.exists(zh_path):
            # Change the base path to /docs/
            page = yaml.load(
                Path(zh_path)
                .read_text(encoding="utf-8")
                .replace('<img src="/assets/docs/', '<img src="/docs/assets/'),
                Loader=yaml.FullLoader,
            )
            print(zh_path)

    for i in range(len(page["children"])):
        page["children"][i] = translate_with_yaml(page["children"][i])
    return page


if __name__ == "__main__":
    # load assets/docs.json docs/i18n/**/*-zh.yaml and combine them into assets/docs.zh.json
    with open("./assets/docs.json", "r", encoding="utf-8") as f:
        docs = json.load(f)
        for i in range(len(docs)):
            docs[i] = translate_with_yaml(docs[i])

        with Path("./assets/docs.zh.json").open("w") as ff:
            json.dump(docs, ff, ensure_ascii=False, indent=2)
