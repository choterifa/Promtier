import Foundation
import LlamaSwift

func test() {
    llama_backend_init()
    var mp = llama_model_default_params()
    let m = llama_load_model_from_file("x", mp)
    var cp = llama_context_default_params()
    let c = llama_new_context_with_model(m, cp)
    var b = llama_batch_init(512, 0, 1)
    let smpl = llama_sampler_init_greedy()
    llama_decode(c, b)
    llama_backend_free()
}