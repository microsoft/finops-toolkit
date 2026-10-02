// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace FinOpsToolkit
{
    public sealed class QuotaBlobStream : Stream
    {
        private readonly Uri blobUri;
        private readonly Func<SecureString> tokenProvider;
        private readonly HttpClient client;
        private readonly byte[] buffer;
        private readonly List<string> blocks = new List<string>();
        private readonly IncrementalHash hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
        private int buffered;
        private long length;
        private bool completed;
        private bool failed;
        private bool disposed;

        public QuotaBlobStream(Uri blobUri, Func<SecureString> tokenProvider, HttpClient client, int blockSize = 8388608)
        {
            if (blobUri == null || blobUri.Scheme != Uri.UriSchemeHttps || !string.IsNullOrEmpty(blobUri.Query))
                throw new ArgumentException("The quota blob URI must use HTTPS without query parameters.", nameof(blobUri));
            if (blockSize < 1 || blockSize > 8388608)
                throw new ArgumentOutOfRangeException(nameof(blockSize));
            this.blobUri = blobUri;
            this.tokenProvider = tokenProvider ?? throw new ArgumentNullException(nameof(tokenProvider));
            this.client = client ?? throw new ArgumentNullException(nameof(client));
            buffer = new byte[blockSize];
        }

        public string Sha256 { get; private set; }
        public int BlockCount => blocks.Count;
        public override long Length => length;
        public override long Position { get => length; set => throw new NotSupportedException(); }
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => !disposed && !completed && !failed;

        public override void Write(byte[] data, int offset, int count)
        {
            EnsureWritable();
            if (data == null) throw new ArgumentNullException(nameof(data));
            if (offset < 0 || count < 0 || offset > data.Length - count)
                throw new ArgumentOutOfRangeException(nameof(count));
            while (count > 0)
            {
                int copied = Math.Min(count, buffer.Length - buffered);
                Buffer.BlockCopy(data, offset, buffer, buffered, copied);
                hash.AppendData(data, offset, copied);
                buffered += copied;
                length += copied;
                offset += copied;
                count -= copied;
                if (buffered == buffer.Length) StageBlock();
            }
        }

        // Flushes must not publish a partial snapshot. Only Complete commits the staged blocks.
        public override void Flush()
        {
            if (disposed) throw new ObjectDisposedException(nameof(QuotaBlobStream));
        }

        public void Complete()
        {
            EnsureWritable();
            if (buffered > 0) StageBlock();
            var list = new StringBuilder("<BlockList>");
            foreach (string block in blocks) list.Append("<Uncommitted>").Append(block).Append("</Uncommitted>");
            list.Append("</BlockList>");
            using (var content = new StringContent(list.ToString(), Encoding.UTF8, "application/xml"))
                Put("?comp=blocklist", content, true);
            Sha256 = Convert.ToHexString(hash.GetHashAndReset()).ToLowerInvariant();
            completed = true;
        }

        private void StageBlock()
        {
            if (blocks.Count >= 50000) throw new IOException("The quota CSV exceeds the block blob limit.");
            string block = Convert.ToBase64String(Encoding.ASCII.GetBytes(blocks.Count.ToString("D8", CultureInfo.InvariantCulture)));
            using (var content = new ByteArrayContent(buffer, 0, buffered))
                Put("?comp=block&blockid=" + Uri.EscapeDataString(block), content, false);
            blocks.Add(block);
            buffered = 0;
        }

        private void Put(string query, HttpContent content, bool commit)
        {
            try
            {
                using (var request = new HttpRequestMessage(HttpMethod.Put, new Uri(blobUri.AbsoluteUri + query)))
                {
                    SecureString token = tokenProvider();
                    if (token == null || token.Length == 0)
                        throw new InvalidOperationException("The storage token provider returned no token.");
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", new NetworkCredential("", token).Password);
                    request.Headers.Add("x-ms-version", "2023-11-03");
                    request.Headers.Add("x-ms-date", DateTime.UtcNow.ToString("R", CultureInfo.InvariantCulture));
                    if (commit)
                    {
                        request.Headers.Add("x-ms-blob-content-type", "text/csv");
                        request.Headers.TryAddWithoutValidation("If-None-Match", "*");
                    }
                    request.Content = content;
                    using (var response = client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead).GetAwaiter().GetResult())
                    {
                        if (!response.IsSuccessStatusCode)
                        {
                            string code = response.Headers.TryGetValues("x-ms-error-code", out var values)
                                ? string.Join(",", values) : response.ReasonPhrase;
                            throw new HttpRequestException($"Quota blob {(commit ? "commit" : "block upload")} failed: HTTP {(int)response.StatusCode} ({code}).");
                        }
                    }
                }
            }
            catch
            {
                failed = true;
                throw;
            }
        }

        private void EnsureWritable()
        {
            if (disposed) throw new ObjectDisposedException(nameof(QuotaBlobStream));
            if (completed || failed) throw new InvalidOperationException("The quota blob stream is completed or failed.");
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing && !disposed)
            {
                disposed = true;
                hash.Dispose();
            }
            base.Dispose(disposing);
        }

        public override int Read(byte[] data, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
    }
}
