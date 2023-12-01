using Amazon.S3;
using Microsoft.AspNetCore.Mvc;

namespace LambdaAPIS3.Controllers;

[ApiController]
[Route("api/buckets")]
public class BucketController : ControllerBase
{
    private readonly IAmazonS3 _s3Client;
    private readonly ILogger<BucketController> _logger;

    public BucketController(IAmazonS3 s3Client, ILogger<BucketController> logger)
    {
        _s3Client = s3Client;
        _logger = logger;
    }
    
    [HttpPost("create")]
    public async Task<IActionResult> CreateBucketAsync(string bucketName)
    {
        var bucketExists = await Amazon.S3.Util.AmazonS3Util.DoesS3BucketExistV2Async(_s3Client, bucketName);
        
        if (bucketExists) 
            return BadRequest($"Bucket {bucketName} already exists.");
        
        await _s3Client.PutBucketAsync(bucketName);
        
        return Ok($"Bucket {bucketName} created.");
    }
    
    [HttpGet("get-all")]
    public async Task<IActionResult> GetAllBucketAsync()
    {
        _logger.LogInformation("Getting all buckets");
        
        var data = await _s3Client.ListBucketsAsync();
        
        _logger.LogInformation("Got all buckets");
        
        var buckets = data.Buckets.Select(b => b.BucketName);
        
        _logger.LogInformation("After Linq");

        return Ok(buckets);
    }
    
    [HttpDelete("delete")]
    public async Task<IActionResult> DeleteBucketAsync(string bucketName)
    {
        await _s3Client.DeleteBucketAsync(bucketName);
        return NoContent();
    }
}