# Models

Model services start manually. Run archive commands on `spark-01`.

## Archive

Commands are resumable.

```sh
ssh spark-01.local models archive \
  deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062
```

## Copy

Copy and verify an archived model on another Spark:

```sh
ssh spark-02.local models ensure \
  deepseek-ai/DeepSeek-V4-Flash-0731@7872f01b1d1fe23eabc4c98b48bffcef5a386062 \
  --source spark-01
```

## DeepSeek V4 Flash

DeepSeek uses `spark-01` and `spark-02`.

```sh
ssh spark-01.local sudo systemctl start infer-deepseek-v4-flash-0731
ssh spark-01.local journalctl -fu infer-deepseek-v4-flash-0731
ssh spark-01.local sudo systemctl stop infer-deepseek-v4-flash-0731
```

## API

The OpenAI-compatible API is `http://spark-01.local:8888/v1`. Both recipes
serve the model as `spark-current`.

```sh
curl --fail http://spark-01.local:8888/v1/models
```
