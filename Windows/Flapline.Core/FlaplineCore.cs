using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Flapline.Windows;

public static class FlaplineCore
{
    public static readonly string[] Drum = TextElements(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-/:").ToArray();

    public static string IdleSuccessor(string current)
    {
        var normalized = TextElements(current).FirstOrDefault() ?? " ";
        var index = Array.IndexOf(Drum, normalized);
        return index < 0 ? " " : Drum[(index + 1) % Drum.Length];
    }

    public static string[,] TextTargets(IEnumerable<string> sourceLines, int rows, int columns)
    {
        var targets = EmptyTargets(rows, columns);
        if (rows == 0 || columns == 0)
        {
            return targets;
        }

        var inset = rows > 2 && columns > 2 ? 1 : 0;
        var contentRows = Math.Max(1, rows - inset * 2);
        var contentColumns = Math.Max(1, columns - inset * 2);
        var lines = sourceLines
            .SelectMany(line => Wrap(TextElements(line), contentColumns))
            .Take(contentRows)
            .ToArray();
        var startRow = inset + Math.Max(0, (contentRows - lines.Length) / 2);

        for (var rowOffset = 0; rowOffset < lines.Length; rowOffset++)
        {
            var line = lines[rowOffset];
            var startColumn = inset + Math.Max(0, (contentColumns - line.Count) / 2);
            for (var column = 0; column < line.Count; column++)
            {
                targets[startRow + rowOffset, startColumn + column] = line[column];
            }
        }

        return targets;
    }

    public static string[,] RandomTargets(int rows, int columns, Random random)
    {
        var targets = EmptyTargets(rows, columns);
        for (var row = 0; row < rows; row++)
        {
            for (var column = 0; column < columns; column++)
            {
                targets[row, column] = Drum[random.Next(Drum.Length)];
            }
        }
        return targets;
    }

    public static IEnumerable<string> TextElements(string value)
    {
        var enumerator = StringInfo.GetTextElementEnumerator(value ?? string.Empty);
        while (enumerator.MoveNext())
        {
            yield return enumerator.GetTextElement().ToUpperInvariant();
        }
    }

    private static string[,] EmptyTargets(int rows, int columns)
    {
        var targets = new string[Math.Max(rows, 0), Math.Max(columns, 0)];
        for (var row = 0; row < targets.GetLength(0); row++)
        {
            for (var column = 0; column < targets.GetLength(1); column++)
            {
                targets[row, column] = " ";
            }
        }
        return targets;
    }

    private static IEnumerable<IReadOnlyList<string>> Wrap(IEnumerable<string> elements, int width)
    {
        var line = new List<string>(width);
        foreach (var element in elements)
        {
            line.Add(element);
            if (line.Count == width)
            {
                yield return line;
                line = new List<string>(width);
            }
        }

        if (line.Count > 0)
        {
            yield return line;
        }
    }
}
