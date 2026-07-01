using System;
using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace MaximumApocalypse.Data
{
    public static class JsonOptions
    {
        public static readonly JsonSerializerOptions Default = new()
        {
            WriteIndented = true,
            PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
            Converters =
            {
                new JsonStringEnumConverter(),
                new Vector2IConverter(),
            },
        };
    }

    /// <summary>
    /// Godot Vector2I 的 JSON 转换器：{ "x": int, "y": int }。
    /// </summary>
    public class Vector2IConverter : JsonConverter<Vector2I>
    {
        public override Vector2I Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType != JsonTokenType.StartObject)
            {
                return Vector2I.Zero;
            }
            int x = 0, y = 0;
            while (reader.Read() && reader.TokenType != JsonTokenType.EndObject)
            {
                if (reader.TokenType == JsonTokenType.PropertyName)
                {
                    string? name = reader.GetString();
                    reader.Read();
                    if (name == "x") x = reader.GetInt32();
                    else if (name == "y") y = reader.GetInt32();
                }
            }
            return new Vector2I(x, y);
        }

        public override void Write(Utf8JsonWriter writer, Vector2I value, JsonSerializerOptions options)
        {
            writer.WriteStartObject();
            writer.WriteNumber("x", value.X);
            writer.WriteNumber("y", value.Y);
            writer.WriteEndObject();
        }
    }
}
